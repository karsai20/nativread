import Foundation

/// The JavaScript pagination engine injected into every chapter.
/// All page math lives here; Swift only sends intents and receives
/// `{type:"state", page, pageCount}` messages back.
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

    static func engine(pageWidth: Double) -> String {
        """
        (function () {
          if (window.lumen) { return; }
          \(ensureViewport)
          const PW = \(pageWidth);
          const lumen = {
            page: 0,
            pageCount: 1,

            layout() {
              // body.scrollWidth, not the scrolling element's: the column
              // boxes overflow the body and html clips them away.
              const total = Math.max(
                document.body.scrollWidth,
                document.scrollingElement.scrollWidth
              );
              this.pageCount = Math.max(1, Math.round(total / PW));
            },

            notify() {
              window.webkit.messageHandlers.lumen.postMessage({
                type: "state",
                page: this.page,
                pageCount: this.pageCount
              });
            },

            goTo(page, animate) {
              this.page = Math.min(Math.max(page, 0), this.pageCount - 1);
              document.body.classList.toggle("lumen-animate", !!animate);
              document.body.style.transform =
                "translate3d(" + (-this.page * PW) + "px, 0, 0)";
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
              if (this.page >= this.pageCount - 1) { return false; }
              this.goTo(this.page + 1, true);
              return true;
            },

            prev() {
              if (this.page <= 0) { return false; }
              this.goTo(this.page - 1, true);
              return true;
            },

            // Snippet of the text currently in the middle of the page,
            // used for bookmark labels.
            snippet() {
              const range = document.caretRangeFromPoint(
                PW / 2, window.innerHeight / 2
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
                    let rect = range.getBoundingClientRect();
                    const absoluteLeft = rect.left + this.page * PW;
                    const target = Math.max(0, Math.floor(absoluteLeft / PW));
                    try {
                      const mark = document.createElement("mark");
                      mark.className = "lumen-find";
                      range.surroundContents(mark);
                    } catch (e) { /* multi-node range: skip highlight */ }
                    this.layout();
                    this.goTo(target, false);
                    return true;
                  }
                  seen += 1;
                  from = at + needle.length;
                }
              }
              return false;
            }
          };

          window.lumen = lumen;

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
