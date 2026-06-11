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

            // Paged flow: apply the horizontal transform with the
            // configured turn animation.
            applyTransform(animate) {
              const body = document.body;
              const x = -this.page * PW;
              const move = () => {
                body.style.transform =
                  "translate3d(" + x + "px, 0, 0)";
              };
              if (animate && this.transition === "fade") {
                body.classList.remove("lumen-animate");
                body.classList.add("lumen-fade");
                body.style.opacity = "0";
                setTimeout(() => {
                  move();
                  body.style.opacity = "1";
                }, 110);
              } else {
                body.classList.remove("lumen-fade");
                body.style.opacity = "1";
                body.classList.toggle("lumen-animate",
                  !!animate && this.transition === "slide");
                move();
              }
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
                this.applyTransform(animate);
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
                      const absoluteLeft = rect.left + this.page * PW;
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

          const start = () => {
            lumen.layout();
            window.webkit.messageHandlers.lumen.postMessage({
              type: "ready",
              pageCount: lumen.pageCount
            });
          };
          if (document.readyState === "complete") {
            requestAnimationFrame(start);
          } else {
            window.addEventListener("load", () => {
              requestAnimationFrame(start);
            });
          }
        })();
        """
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
