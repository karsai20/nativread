import Foundation

/// The JavaScript reading engine injected into every chapter.
/// All page/scroll math lives here; Swift only sends intents and
/// receives `{type:"state"|"tap"|"swipe"|...}` messages back.
enum ReaderScripts {

    /// EPUB chapters rarely ship a viewport meta tag, so WKWebView would
    /// lay them out at its 980px legacy viewport and scale down. Force a
    /// device-width viewport before any page math happens.
    static let ensureViewport = """
    (function () {
      let meta = document.querySelector('meta[name="viewport"]');
      if (!meta) {
        meta = document.createElement("meta");
        meta.setAttribute("name", "viewport");
        (document.head || document.documentElement).appendChild(meta);
      }
      meta.setAttribute("content",
        "width=device-width, initial-scale=1, maximum-scale=1, " +
        "user-scalable=no");
    })();
    """

    /// Fraction of the viewport width on each side that acts as a
    /// page-turn tap zone; the middle toggles the chrome.
    static let tapZoneFraction = 0.24

    static func engine(
        pageWidth: Double, flow: PageFlow, transition: PageTransition
    ) -> String {
        """
        (function () {
          if (window.lumen) { return; }
          \(ensureViewport)
          const PW = \(pageWidth);
          const MODE = "\(flow.rawValue)";
          const ZONE = \(tapZoneFraction);
          const lumen = {
            page: 0,
            pageCount: 1,
            transition: "\(transition.rawValue)",

            scroller() { return document.scrollingElement; },
            maxScroll() {
              return Math.max(
                0, this.scroller().scrollHeight - window.innerHeight
              );
            },

            layout() {
              if (MODE === "scroll") {
                // Synthetic pages: one viewport-height per "page" so the
                // existing progress plumbing keeps working unchanged.
                // ceil, not round: any scrollable overflow is a page.
                this.pageCount = Math.max(1, Math.ceil(
                  this.scroller().scrollHeight / window.innerHeight - 0.02
                ));
              } else {
                // body.scrollWidth, not the scrolling element's: the
                // column boxes overflow the body and html clips them.
                const total = Math.max(
                  document.body.scrollWidth,
                  document.scrollingElement.scrollWidth
                );
                this.pageCount = Math.max(1, Math.round(total / PW));
              }
            },

            notify() {
              window.webkit.messageHandlers.lumen.postMessage({
                type: "state",
                page: this.page,
                pageCount: this.pageCount
              });
            },

            // Paged flow turns pages by horizontally scrolling the
            // native UIScrollView — a CSS transform leaves WebKit's
            // off-screen tiles unpainted, and a JS scrollTo does not
            // reliably move WKWebView's scroll view. So the engine asks
            // Swift to set the content offset; it only owns the
            // transition animation (opacity / e-ink flash) here.
            postScroll(animate) {
              window.webkit.messageHandlers.lumen.postMessage({
                type: "scroll", x: this.page * PW, animate: !!animate
              });
            },

            movePaged(animate) {
              const body = document.body;
              if (animate && this.transition === "slide") {
                body.classList.remove("lumen-fade");
                body.style.opacity = "1";
                this.postScroll(true);
              } else if (animate && this.transition === "fade") {
                body.classList.add("lumen-fade");
                body.style.opacity = "0";
                setTimeout(() => {
                  this.postScroll(false);
                  body.style.opacity = "1";
                }, 110);
              } else if (animate && this.transition === "eink") {
                body.classList.remove("lumen-fade");
                this.einkFlash(() => this.postScroll(false));
              } else {
                body.classList.remove("lumen-fade");
                body.style.opacity = "1";
                this.postScroll(false);
              }
            },

            // The signature e-ink refresh: the screen blinks to ink
            // while the page is swapped underneath. The overlay lives
            // outside <body> so the page transform can't move it.
            einkFlash(move) {
              let flash = document.getElementById("lumen-eink");
              if (!flash) {
                flash = document.createElement("div");
                flash.id = "lumen-eink";
                document.documentElement.appendChild(flash);
              }
              flash.classList.add("lumen-eink-on");
              setTimeout(() => {
                move();
                flash.classList.remove("lumen-eink-on");
              }, 90);
            },

            goTo(page, animate) {
              this.page = Math.min(Math.max(page, 0), this.pageCount - 1);
              if (MODE === "scroll") {
                const top = this.pageCount > 1
                  ? (this.page / (this.pageCount - 1)) * this.maxScroll()
                  : 0;
                this.scroller().scrollTo({
                  top: top, behavior: animate ? "smooth" : "auto"
                });
              } else {
                this.movePaged(animate);
              }
              this.notify();
            },

            goToFraction(fraction, animate) {
              this.goTo(Math.round(fraction * (this.pageCount - 1)), animate);
            },

            fraction() {
              return this.pageCount > 1
                ? this.page / (this.pageCount - 1) : 0;
            },

            next() {
              if (MODE === "scroll") {
                const el = this.scroller();
                if (el.scrollTop >= this.maxScroll() - 2) { return false; }
                el.scrollTo({
                  top: Math.min(
                    el.scrollTop + window.innerHeight * 0.92,
                    this.maxScroll()
                  ),
                  behavior: "smooth"
                });
                return true;
              }
              if (this.page >= this.pageCount - 1) { return false; }
              this.goTo(this.page + 1, true);
              return true;
            },

            prev() {
              if (MODE === "scroll") {
                const el = this.scroller();
                if (el.scrollTop <= 2) { return false; }
                el.scrollTo({
                  top: Math.max(
                    el.scrollTop - window.innerHeight * 0.92, 0
                  ),
                  behavior: "smooth"
                });
                return true;
              }
              if (this.page <= 0) { return false; }
              this.goTo(this.page - 1, true);
              return true;
            },

            // Snippet of the text currently in the middle of the view,
            // used for bookmark labels.
            snippet() {
              const range = document.caretRangeFromPoint(
                window.innerWidth / 2, window.innerHeight / 2
              );
              const text = range && range.startContainer
                ? (range.startContainer.textContent || "") : "";
              const clean = text.replace(/\\s+/g, " ").trim();
              return clean.length > 90
                ? clean.slice(0, 90) + "\\u2026" : clean;
            },

            // Jumps to the n-th occurrence of `query` and highlights it.
            locate(query, occurrence) {
              document.querySelectorAll("mark.lumen-find").forEach((m) => {
                m.replaceWith(...m.childNodes);
              });
              document.body.normalize();
              const walker = document.createTreeWalker(
                document.body, NodeFilter.SHOW_TEXT
              );
              const needle = query.toLowerCase();
              let seen = 0;
              let node;
              while ((node = walker.nextNode())) {
                const hay = node.textContent.toLowerCase();
                let from = 0;
                let at;
                while ((at = hay.indexOf(needle, from)) !== -1) {
                  if (seen === occurrence) {
                    const range = document.createRange();
                    range.setStart(node, at);
                    range.setEnd(node, at + query.length);
                    const rect = range.getBoundingClientRect();
                    try {
                      const mark = document.createElement("mark");
                      mark.className = "lumen-find";
                      range.surroundContents(mark);
                    } catch (e) { /* multi-node range: skip highlight */ }
                    this.layout();
                    if (MODE === "scroll") {
                      const top = rect.top + this.scroller().scrollTop
                        - window.innerHeight / 2;
                      this.scroller().scrollTo({
                        top: Math.max(0, top), behavior: "auto"
                      });
                      this.syncScrollPage();
                    } else {
                      const absoluteLeft =
                        rect.left + this.scroller().scrollLeft;
                      this.goTo(
                        Math.max(0, Math.floor(absoluteLeft / PW)), false
                      );
                    }
                    return true;
                  }
                  seen += 1;
                  from = at + needle.length;
                }
              }
              return false;
            },

            syncScrollPage() {
              // Re-measure first: late font/image loads grow the
              // document after the initial "ready" measurement.
              this.layout();
              const max = this.maxScroll();
              const f = max > 0 ? this.scroller().scrollTop / max : 0;
              this.page = Math.round(f * (this.pageCount - 1));
              this.notify();
            },

            // Paged flow: the user can flick the native pager to a
            // different page; re-read it from the horizontal offset.
            syncPagedPage() {
              this.page = Math.round(this.scroller().scrollLeft / PW);
              this.notify();
            },

            // Concatenated body text with per-text-node offsets, the
            // basis for relayout-proof highlight anchoring.
            bodyTextMap() {
              const walker = document.createTreeWalker(
                document.body, NodeFilter.SHOW_TEXT
              );
              const nodes = [];
              let text = "";
              let node;
              while ((node = walker.nextNode())) {
                nodes.push({ node: node, start: text.length });
                text += node.textContent;
              }
              return { nodes: nodes, text: text };
            },

            // The n-th occurrence of `needle`, as per-text-node
            // segments (a match may span inline element boundaries).
            findOccurrence(needle, occurrence) {
              const map = this.bodyTextMap();
              const hay = map.text.toLowerCase();
              const n = needle.toLowerCase();
              if (!n.length) { return null; }
              let from = 0;
              let seen = 0;
              let at;
              while ((at = hay.indexOf(n, from)) !== -1) {
                if (seen === occurrence) {
                  const end = at + n.length;
                  const segments = [];
                  for (const entry of map.nodes) {
                    const ns = entry.start;
                    const ne = ns + entry.node.textContent.length;
                    const s = Math.max(at, ns);
                    const e = Math.min(end, ne);
                    if (s < e) {
                      segments.push({
                        node: entry.node, start: s - ns, end: e - ns
                      });
                    }
                  }
                  return segments;
                }
                seen += 1;
                from = at + n.length;
              }
              return null;
            },

            // {text, occurrence} for the current selection, or null
            // when it cannot be re-anchored later.
            selectionLocator() {
              const selection = window.getSelection();
              if (!selection || selection.isCollapsed
                  || !selection.rangeCount) { return null; }
              const range = selection.getRangeAt(0);
              const text = selection.toString();
              if (!text.trim().length) { return null; }
              const map = this.bodyTextMap();
              let absolute = -1;
              for (const entry of map.nodes) {
                if (entry.node === range.startContainer) {
                  absolute = entry.start + range.startOffset;
                  break;
                }
              }
              const hay = map.text.toLowerCase();
              const needle = text.toLowerCase();
              let from = 0;
              let seen = 0;
              let at;
              while ((at = hay.indexOf(needle, from)) !== -1) {
                if (absolute >= 0 && at >= absolute) { break; }
                seen += 1;
                from = at + needle.length;
              }
              if (at === -1) { return null; }
              return { text: text, occurrence: seen };
            },

            clearSelection() {
              const selection = window.getSelection();
              if (selection) { selection.removeAllRanges(); }
            },

            // Redraws all stored highlights for this chapter. Clears
            // previous marks first so the call is idempotent.
            applyHighlights(list) {
              document.querySelectorAll("mark.lumen-highlight")
                .forEach((m) => { m.replaceWith(...m.childNodes); });
              document.body.normalize();
              for (const item of list) {
                const segments = this.findOccurrence(
                  item.text, item.occurrence
                );
                if (!segments) { continue; }
                for (const seg of segments) {
                  const range = document.createRange();
                  range.setStart(seg.node, seg.start);
                  range.setEnd(seg.node, seg.end);
                  try {
                    const mark = document.createElement("mark");
                    mark.className = "lumen-highlight";
                    range.surroundContents(mark);
                  } catch (e) { /* node mutated mid-walk: skip */ }
                }
              }
            }
          };

          window.lumen = lumen;

          if (MODE === "scroll") {
            let ticking = false;
            window.addEventListener("scroll", () => {
              if (ticking) { return; }
              ticking = true;
              requestAnimationFrame(() => {
                ticking = false;
                lumen.syncScrollPage();
              });
            }, { passive: true });
            window.addEventListener("resize", () => {
              lumen.syncScrollPage();
            });
            // Late layout settle (web fonts, images) shifts heights;
            // re-measure once things calm down.
            setTimeout(() => { lumen.syncScrollPage(); }, 350);
          }

          // Gestures live in the page so native text selection can
          // coexist with page turning. A tap with an active selection
          // only dismisses the selection.
          document.addEventListener("click", (event) => {
            event.preventDefault();
            const selection = window.getSelection();
            if (selection && !selection.isCollapsed) { return; }
            const x = event.clientX / window.innerWidth;
            const zone = x < ZONE
              ? "left" : (x > 1 - ZONE ? "right" : "center");
            window.webkit.messageHandlers.lumen.postMessage({
              type: "tap", zone: zone
            });
          }, true);

          let touchStartX = 0;
          let touchStartY = 0;
          document.addEventListener("touchstart", (event) => {
            touchStartX = event.touches[0].clientX;
            touchStartY = event.touches[0].clientY;
          }, { passive: true });
          document.addEventListener("touchend", (event) => {
            if (MODE !== "paged") { return; }
            const dx = event.changedTouches[0].clientX - touchStartX;
            const dy = event.changedTouches[0].clientY - touchStartY;
            if (Math.abs(dx) < 56 || Math.abs(dx) < Math.abs(dy)) {
              return;
            }
            const selection = window.getSelection();
            if (selection && !selection.isCollapsed) { return; }
            window.webkit.messageHandlers.lumen.postMessage({
              type: "swipe",
              direction: dx < 0 ? "forward" : "backward"
            });
          }, { passive: true });

          // Reveal as soon as the text is layouted (DOMContentLoaded):
          // waiting for the full load event leaves the page blank for
          // as long as a slow or missing image keeps loading.
          let started = false;
          const start = () => {
            if (started) { return; }
            started = true;
            lumen.layout();
            window.webkit.messageHandlers.lumen.postMessage({
              type: "ready",
              pageCount: lumen.pageCount
            });
          };
          // Re-measure after layout-affecting resources settle. External
          // stylesheets and web fonts (which the synthetic sample never
          // had) apply after our initial reveal and change the column
          // count, so pageCount and the scrollable width must be
          // recomputed while keeping the reading position.
          const remeasure = () => {
            if (!started) { start(); return; }
            const f = lumen.fraction();
            lumen.layout();
            lumen.goToFraction(f, false);
          };
          if (document.readyState !== "loading") {
            requestAnimationFrame(start);
          } else {
            document.addEventListener("DOMContentLoaded", () => {
              requestAnimationFrame(start);
            });
          }
          window.addEventListener("load", () => {
            requestAnimationFrame(remeasure);
          });
          // Web fonts swap metrics in after load; recompute when ready.
          if (document.fonts && document.fonts.ready) {
            document.fonts.ready.then(() => requestAnimationFrame(remeasure));
          }
          // Linked stylesheets may apply after first paint.
          document.querySelectorAll('link[rel="stylesheet"]').forEach((l) => {
            l.addEventListener("load", () => requestAnimationFrame(remeasure));
          });
          // Settle ticks for anything else (late images, slow CSSOM).
          setTimeout(remeasure, 300);
          setTimeout(remeasure, 900);
          // Belt and braces: never leave the page hidden.
          setTimeout(start, 1500);
        })();
        """
    }

    /// JSON payload for `applyHighlights`, safe to interpolate into a
    /// JS expression (escapes the line separators JSON allows but JS
    /// string literals reject).
    static func highlightsJSON(_ highlights: [Highlight]) -> String {
        let locators = highlights.map {
            ["text": $0.text, "occurrence": $0.occurrence] as [String: Any]
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: locators
        ), let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    /// Wraps the settings CSS in a <style> tag managed by us, replacing
    /// any previous one, then relayouts while keeping the position.
    static func applyStyle(css: String) -> String {
        let escaped = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        return """
        (function () {
          \(ensureViewport)
          let style = document.getElementById("lumen-style");
          if (!style) {
            style = document.createElement("style");
            style.id = "lumen-style";
            document.documentElement.appendChild(style);
          }
          style.textContent = `\(escaped)`;
          if (window.lumen) {
            const f = window.lumen.fraction();
            window.lumen.layout();
            window.lumen.goToFraction(f, false);
          }
        })();
        """
    }
}
