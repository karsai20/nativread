import Foundation

/// The JavaScript reading engine injected into every chapter.
/// All page/scroll math lives here; Swift only sends intents and
/// receives `{type:"state"|"tap"|...}` messages back.
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
            fadeInFlight: false,

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

            // Scroll flow: ask Swift to glide the native scroll view to a
            // vertical offset (CSS px == points at initial-scale=1).
            scrollVTo(y) {
              window.webkit.messageHandlers.lumen.postMessage({
                type: "scrollV", y: y
              });
            },

            movePaged(animate) {
              const body = document.body;
              if (animate && this.transition === "curl") {
                body.style.opacity = "1";
                this.curlStart();
              } else if (animate && this.transition === "slide") {
                body.style.opacity = "1";
                this.postScroll(true);
              } else if (animate && this.transition === "eink") {
                // "eink" is the legacy-persisted rawValue of the Fade case.
                this.fadeSwap(() => this.postScroll(false));
              } else {
                body.style.opacity = "1";
                this.postScroll(false);
              }
            },

            // --- Curl page turn ---------------------------------------
            // A photo of the OUTGOING page is bent around a cylinder on a
            // transparent WebGL canvas floating over the content, while
            // the live page jumps instantly underneath. The canvas is
            // see-through wherever the sheet has peeled away, so the
            // reader watches the real new page emerge under the lifting
            // old one. Only the old page is ever photographed (it is
            // still on screen when Swift snaps it), so no capture can
            // race WebKit's paint of the destination column.
            curlBroken: false,
            curlLive: null,

            // Ask Swift for the bitmap; the turn continues in curlBegin.
            curlStart() {
              if (this.curlBroken || !window.WebGLRenderingContext) {
                this.curlBroken = true;
                this.postScroll(true);
                return;
              }
              if (this.curlLive) { this.curlLive.stop(); }
              const x = this.page * PW;
              const forward = x > this.scroller().scrollLeft + 1;
              window.webkit.messageHandlers.lumen.postMessage({
                type: "captureCurl", x: x, forward: forward
              });
            },

            // Swift could not produce a snapshot: latch off for this
            // chapter and finish the pending turn as a spring slide.
            curlFailed(x) {
              this.curlBroken = true;
              window.webkit.messageHandlers.lumen.postMessage({
                type: "scroll", x: x, animate: true
              });
            },

            curlBegin(dataUrl, forward, x) {
              const drag = this.curlDrag && !this.curlDrag.edge
                && this.curlDrag.toX === x;
              const fail = () => {
                if (drag) {
                  // The finger owns a drag: latch off and let the
                  // release fall back to a spring turn — never yank the
                  // page mid-touch.
                  this.curlBroken = true;
                  this.curlDrag = null;
                } else {
                  this.curlFailed(x);
                }
              };
              const img = new Image();
              img.onload = () => {
                try {
                  if (drag) { this.curlRunDrag(img); }
                  else { this.curlRun(img, forward, x); }
                } catch (e) { fail(); }
              };
              img.onerror = fail;
              img.src = dataUrl;
            },

            curlRun(img, forward, x) {
              const sheet = this.curlMakeSheet(img);
              const run = { stop: null };
              this.curlLive = run;
              const DURATION = 440;
              // Belt and braces: never leave the overlay stuck if the
              // animation frames stop coming (app backgrounded mid-turn).
              const safety = setTimeout(() => run.stop(), 1500);
              run.stop = () => {
                if (this.curlLive === run) { this.curlLive = null; }
                clearTimeout(safety);
                sheet.dispose();
              };
              // First frame: the flat photo exactly covers the live page.
              // Only after that frame is committed may the page jump
              // underneath — the same no-flash ordering as the fade veil.
              sheet.draw(0, forward);
              requestAnimationFrame(() => requestAnimationFrame(() => {
                if (this.curlLive !== run) { return; }
                window.webkit.messageHandlers.lumen.postMessage({
                  type: "scroll", x: x, animate: false
                });
                const t0 = performance.now();
                const ease = (t) =>
                  t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t);
                const step = (now) => {
                  if (this.curlLive !== run) { return; }
                  const t = Math.min(1, (now - t0) / DURATION);
                  sheet.draw(ease(t), forward);
                  if (t < 1) { requestAnimationFrame(step); }
                  else { run.stop(); }
                };
                requestAnimationFrame(step);
              }));
            },

            // --- Finger-tracked curl (drag scrub) ---------------------
            // Same captured-overlay pipeline as the tap turn, but
            // progress follows the finger and the release commits (a
            // flick, or past halfway) or settles back. The touch
            // handlers at the bottom of the engine feed these.
            curlDrag: null,

            curlDragBegin(forward, touchId) {
              if (this.curlLive) { return; }
              const atEdge = forward
                ? this.page >= this.pageCount - 1
                : this.page <= 0;
              if (atEdge) {
                // Chapter boundary: no in-chapter page to curl to. Track
                // the pull and report it on release so Swift can advance
                // the chapter (native overscroll is disabled in curl
                // mode).
                this.curlDrag = {
                  edge: forward ? "forward" : "backward",
                  touchId: touchId, dx: 0
                };
                return;
              }
              if (this.curlBroken || !window.WebGLRenderingContext) {
                // Degraded: no visual scrub, but a committed release
                // still turns the page with the spring slide.
                this.curlDrag = {
                  edge: null, fallback: true, forward: forward,
                  touchId: touchId, progress: 0,
                  t0: performance.now(), sheet: null, ended: null
                };
                return;
              }
              const toX = (this.page + (forward ? 1 : -1)) * PW;
              this.curlDrag = {
                edge: null, fallback: false, forward: forward,
                touchId: touchId, fromX: this.page * PW, toX: toX,
                progress: 0, grabY: 0.5, t0: performance.now(),
                sheet: null, run: null, ended: null
              };
              window.webkit.messageHandlers.lumen.postMessage({
                type: "captureCurl", x: toX, forward: forward
              });
            },

            // The captured bitmap arrived for an in-flight drag: mount
            // the sheet at the finger's current progress, turn the live
            // page instantly underneath, and apply a release that beat
            // the capture round-trip.
            curlRunDrag(img) {
              const drag = this.curlDrag;
              if (!drag || drag.edge || drag.fallback) { return; }
              const sheet = this.curlMakeSheet(img);
              const run = { stop: null };
              this.curlLive = run;
              run.stop = () => {
                if (this.curlLive === run) { this.curlLive = null; }
                if (this.curlDrag === drag) { this.curlDrag = null; }
                sheet.dispose();
              };
              drag.sheet = sheet;
              drag.run = run;
              sheet.draw(drag.progress, drag.forward, drag.grabY);
              requestAnimationFrame(() => requestAnimationFrame(() => {
                if (this.curlLive !== run) { return; }
                window.webkit.messageHandlers.lumen.postMessage({
                  type: "scroll", x: drag.toX, animate: false
                });
                if (drag.ended) {
                  const commit = drag.ended.commit;
                  drag.ended = null;
                  this.curlDragFinish(drag, commit);
                }
              }));
            },

            curlDragFinish(drag, commit) {
              if (drag.fallback) {
                this.curlDrag = null;
                if (commit) {
                  this.goTo(this.page + (drag.forward ? 1 : -1), true);
                }
                return;
              }
              if (!drag.sheet) {
                // Capture still in flight; curlRunDrag applies this.
                drag.ended = { commit: commit };
                return;
              }
              const run = drag.run;
              const sheet = drag.sheet;
              const from = drag.progress;
              const target = commit ? 1 : 0;
              if (commit) {
                // State first: an interrupted settle must never leave
                // the engine pointing at a column the live view left.
                this.page = Math.round(drag.toX / PW);
                this.notify();
              }
              const duration = Math.max(80, 360 * Math.abs(target - from));
              const t0 = performance.now();
              const ease = (t) =>
                t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t);
              const step = (now) => {
                if (this.curlLive !== run) { return; }
                const k = Math.min(1, (now - t0) / duration);
                sheet.draw(
                  from + (target - from) * ease(k),
                  drag.forward, drag.grabY
                );
                if (k < 1) { requestAnimationFrame(step); return; }
                if (commit) { run.stop(); return; }
                // Cancelled: the sheet lies flat again covering the
                // page; jump the live view back underneath, let it
                // repaint, then uncover.
                window.webkit.messageHandlers.lumen.postMessage({
                  type: "scroll", x: drag.fromX, animate: false
                });
                requestAnimationFrame(() => requestAnimationFrame(() => {
                  run.stop();
                }));
              };
              requestAnimationFrame(step);
            },

            // Builds the one-turn WebGL overlay: a grid mesh of the page
            // photo plus the cylinder-wrap vertex math. Classic geometry:
            // content before the fold stays flat; within half a
            // circumference it winds around a cylinder of radius R
            // (offset d - R*sin(d/R), lift R*(1-cos(d/R))); past that it
            // lies flat on top, mirrored about the fold. Throws when
            // WebGL is unavailable so the caller can fall back.
            curlMakeSheet(img) {
              const W = window.innerWidth;
              const H = window.innerHeight;
              const dpr = Math.min(2, window.devicePixelRatio || 1);
              const canvas = document.createElement("canvas");
              canvas.id = "lumen-curl";
              canvas.width = Math.round(W * dpr);
              canvas.height = Math.round(H * dpr);
              canvas.style.cssText = "position:fixed;left:0;top:0;width:"
                + W + "px;height:" + H
                + "px;pointer-events:none;z-index:2147483000;";
              document.documentElement.appendChild(canvas);
              const gl = canvas.getContext("webgl", {
                alpha: true, premultipliedAlpha: true
              });
              if (!gl) {
                canvas.remove();
                throw new Error("webgl unavailable");
              }
              const vsrc = [
                "attribute vec2 aXY;",
                "uniform vec2 uSize;",
                "uniform vec2 uFold;",
                "uniform vec2 uDir;",
                "uniform float uR;",
                "varying vec2 vXY;",
                "varying float vLift;",
                "const float PI = 3.14159265358979;",
                "void main() {",
                "  vec2 pos = aXY * uSize;",
                "  float d = dot(pos - uFold, uDir);",
                "  float lift = 0.0;",
                "  if (d > 0.0) {",
                "    if (d < PI * uR) {",
                "      pos -= uDir * (d - uR * sin(d / uR));",
                "      lift = uR * (1.0 - cos(d / uR));",
                "    } else {",
                "      pos -= uDir * (2.0 * d - PI * uR);",
                "      lift = 2.0 * uR;",
                "    }",
                "  }",
                "  vXY = aXY;",
                "  vLift = lift / (2.0 * uR);",
                "  vec2 clip = pos / uSize * 2.0 - 1.0;",
                "  gl_Position = vec4(clip.x, -clip.y, -vLift * 0.5, 1.0);",
                "}"
              ].join("\\n");
              const fsrc = [
                "precision mediump float;",
                "uniform sampler2D uSheet;",
                "uniform vec3 uPaper;",
                "varying vec2 vXY;",
                "varying float vLift;",
                "void main() {",
                "  vec4 ink = texture2D(uSheet, vXY);",
                "  if (gl_FrontFacing) {",
                "    ink.rgb *= 1.0 - 0.16 * vLift;",
                "  } else {",
                // The underside: content bleeding through the theme's
                // paper — never plain white, which flares in dark mode.
                "    ink.rgb = mix(ink.rgb, uPaper, 0.75);",
                "    ink.rgb *= 1.0 - 0.06 * vLift;",
                "  }",
                "  gl_FragColor = ink;",
                "}"
              ].join("\\n");
              const compile = (kind, src) => {
                const shader = gl.createShader(kind);
                gl.shaderSource(shader, src);
                gl.compileShader(shader);
                if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
                  throw new Error(gl.getShaderInfoLog(shader));
                }
                return shader;
              };
              const program = gl.createProgram();
              gl.attachShader(program, compile(gl.VERTEX_SHADER, vsrc));
              gl.attachShader(program, compile(gl.FRAGMENT_SHADER, fsrc));
              gl.linkProgram(program);
              if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
                throw new Error(gl.getProgramInfoLog(program));
              }
              gl.useProgram(program);
              // GRID x GRID quads over the unit page.
              const GRID = 40;
              const verts = [];
              for (let gy = 0; gy <= GRID; gy++) {
                for (let gx = 0; gx <= GRID; gx++) {
                  verts.push(gx / GRID, gy / GRID);
                }
              }
              const indices = [];
              const at = (gx, gy) => gy * (GRID + 1) + gx;
              for (let gy = 0; gy < GRID; gy++) {
                for (let gx = 0; gx < GRID; gx++) {
                  indices.push(at(gx, gy), at(gx + 1, gy), at(gx, gy + 1));
                  indices.push(
                    at(gx + 1, gy), at(gx + 1, gy + 1), at(gx, gy + 1)
                  );
                }
              }
              gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
              gl.bufferData(
                gl.ARRAY_BUFFER, new Float32Array(verts), gl.STATIC_DRAW
              );
              const aXY = gl.getAttribLocation(program, "aXY");
              gl.enableVertexAttribArray(aXY);
              gl.vertexAttribPointer(aXY, 2, gl.FLOAT, false, 0, 0);
              gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl.createBuffer());
              gl.bufferData(
                gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices),
                gl.STATIC_DRAW
              );
              gl.bindTexture(gl.TEXTURE_2D, gl.createTexture());
              gl.texImage2D(
                gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img
              );
              gl.texParameteri(
                gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR
              );
              gl.texParameteri(
                gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR
              );
              gl.texParameteri(
                gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE
              );
              gl.texParameteri(
                gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE
              );
              const uni = {};
              ["uSize", "uFold", "uDir", "uR", "uSheet", "uPaper"]
                .forEach((n) => {
                  uni[n] = gl.getUniformLocation(program, n);
                });
              gl.uniform2f(uni.uSize, W, H);
              gl.uniform1i(uni.uSheet, 0);
              // The theme's paper color, read from the live page so the
              // sheet's underside matches dark and sepia themes alike.
              const readPaper = (el) => {
                const c = getComputedStyle(el).backgroundColor || "";
                const open = c.indexOf("(");
                const close = c.indexOf(")");
                if (open < 0 || close < 0) { return null; }
                const parts = c.slice(open + 1, close)
                  .split(",").map(parseFloat);
                if (parts.length > 3 && parts[3] === 0) { return null; }
                return [parts[0] / 255, parts[1] / 255, parts[2] / 255];
              };
              const paper = readPaper(document.body)
                || readPaper(document.documentElement)
                || [1, 1, 1];
              gl.uniform3f(uni.uPaper, paper[0], paper[1], paper[2]);
              gl.viewport(0, 0, canvas.width, canvas.height);
              gl.enable(gl.DEPTH_TEST);
              gl.disable(gl.CULL_FACE);
              // Clip-space y is flipped in the vertex shader, which flips
              // triangle winding too; without this the front/back test
              // (page face vs whitened underside) is inverted.
              gl.frontFace(gl.CW);
              gl.enable(gl.BLEND);
              gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
              return {
                // progress 0 = flat photo, 1 = fully peeled away.
                // The sheet is pinched where it was grabbed: tap turns
                // pinch near the lower outer corner, drags follow the
                // finger's row. The fold starts as a diagonal there and
                // straightens as the turn completes, so the whole page
                // clears by the end.
                draw(progress, forward, grabYIn) {
                  const grabY = grabYIn === undefined ? 0.78 : grabYIn;
                  const tilt = (grabY - 0.5) * 1.6 * (1 - progress);
                  const sx = forward ? 1 : -1;
                  const norm = Math.hypot(1, tilt);
                  const dirX = sx / norm;
                  const dirY = tilt / norm;
                  // The cylinder tightens a little as the page lifts.
                  const R = Math.max(20, W * 0.15 * (1 - 0.35 * progress));
                  // To fully clear, the fold must cross the page width
                  // plus the final half-circumference.
                  const REnd = Math.max(20, W * 0.15 * 0.65);
                  const sweep = (W + Math.PI * REnd) * progress;
                  const foldX = (forward ? W : 0) - dirX * sweep;
                  const foldY = grabY * H - dirY * sweep;
                  gl.clearColor(0, 0, 0, 0);
                  gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
                  gl.uniform2f(uni.uFold, foldX, foldY);
                  gl.uniform2f(uni.uDir, dirX, dirY);
                  gl.uniform1f(uni.uR, R);
                  gl.drawElements(
                    gl.TRIANGLES, indices.length, gl.UNSIGNED_SHORT, 0
                  );
                },
                dispose() {
                  const lose = gl.getExtension("WEBGL_lose_context");
                  if (lose) { lose.loseContext(); }
                  canvas.remove();
                }
              };
            },

            // Kindle-style fade: the old page washes out to blank paper
            // (a page-background veil), the page is swapped underneath,
            // then the veil eases away over the new page. The overlay
            // lives outside <body> so the page transform can't move it.
            // The swap happens at peak opacity so the reader never sees
            // the pages cross-fade.
            fadeSwap(move) {
              this.fadeInFlight = true;
              let veil = document.getElementById("lumen-fade");
              if (!veil) {
                veil = document.createElement("div");
                veil.id = "lumen-fade";
                document.documentElement.appendChild(veil);
              }
              veil.classList.add("lumen-fade-on");
              // Wait for the veil to be FULLY opaque (120ms fade-in + a
              // hair), swap the page behind it, give WebKit one more frame
              // to paint the new column, then ease the veil away — so the
              // reveal is the crisp finished page, never a half-painted
              // cross-fade.
              setTimeout(() => {
                move();
                requestAnimationFrame(() => requestAnimationFrame(() => {
                  veil.classList.remove("lumen-fade-on");
                  this.fadeInFlight = false;
                }));
              }, 140);
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
                // Let Swift glide the native scroll view: WKWebView's JS
                // `scrollTo({behavior:"smooth"})` is steppy on iOS, the native
                // animation is 60fps and matches the paged-flow turn.
                this.scrollVTo(Math.min(
                  el.scrollTop + window.innerHeight * 0.9, this.maxScroll()
                ));
                return true;
              }
              if (this.transition === "eink" && this.fadeInFlight) {
                return true;
              }
              if (this.curlDrag) { return true; }
              if (this.page >= this.pageCount - 1) { return false; }
              this.goTo(this.page + 1, true);
              return true;
            },

            prev() {
              if (MODE === "scroll") {
                const el = this.scroller();
                if (el.scrollTop <= 2) { return false; }
                this.scrollVTo(Math.max(
                  el.scrollTop - window.innerHeight * 0.9, 0
                ));
                return true;
              }
              if (this.transition === "eink" && this.fadeInFlight) {
                return true;
              }
              if (this.curlDrag) { return true; }
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
              // Hot path: runs while the user scrolls. Must NOT call
              // layout() — reading scrollHeight forces a synchronous
              // reflow every frame and makes scrolling stutter. The
              // page count only changes on resize/late-load, which call
              // remeasureScroll() instead.
              const max = this.maxScroll();
              const f = max > 0 ? this.scroller().scrollTop / max : 0;
              this.page = Math.round(f * (this.pageCount - 1));
              this.notify();
            },

            // Re-measure the document (late font/image loads grow it),
            // then resync. Called on resize/load, never per scroll frame.
            remeasureScroll() {
              this.layout();
              this.syncScrollPage();
            },

            // Paged flow: the user can flick the native pager to a
            // different page; re-read it from the horizontal offset.
            // Clamped: a rubber-band offset can round outside the range.
            syncPagedPage() {
              this.page = Math.min(Math.max(
                Math.round(this.scroller().scrollLeft / PW), 0
              ), this.pageCount - 1);
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

            // The current selection's plain text, trimmed, or "" when
            // nothing usable is selected. Drives the Define lookup.
            selectedText() {
              const selection = window.getSelection();
              if (!selection || selection.isCollapsed
                  || !selection.rangeCount) { return ""; }
              return (selection.toString() || "").replace(/\\s+/g, " ").trim();
            },

            // The sentence the current selection sits in, for saving a
            // word with its reading context. Pure DOM read: expands from
            // the selection's text node out to the nearest .!?… (or block)
            // boundaries, collapses whitespace, and returns "" when no
            // usable context can be derived. Never lays out, scrolls, or
            // mutates the DOM or engine state.
            selectionSentence() {
              const selection = window.getSelection();
              if (!selection || selection.isCollapsed
                  || !selection.rangeCount) { return ""; }
              const range = selection.getRangeAt(0);
              const selected = (selection.toString() || "").trim();
              if (!selected.length) { return ""; }
              // Read the enclosing text from the common ancestor; for a
              // selection inside one text node that is the paragraph.
              let host = range.commonAncestorContainer;
              if (host.nodeType === Node.TEXT_NODE) {
                host = host.parentNode;
              }
              if (!host) { return ""; }
              const block = host.textContent || "";
              if (!block.length) { return ""; }
              // Locate the selection within the block text. Prefer an
              // exact match; fall back to the block itself if not found.
              const lower = block.toLowerCase();
              const at = lower.indexOf(selected.toLowerCase());
              const TERMINATORS = ".!?\\u2026";
              const isEnd = (ch) => TERMINATORS.indexOf(ch) !== -1;
              let from = 0;
              let to = block.length;
              if (at !== -1) {
                // Walk left to the char after the previous terminator.
                for (let i = at - 1; i >= 0; i--) {
                  if (isEnd(block[i])) { from = i + 1; break; }
                }
                // Walk right to and including the next terminator.
                const selEnd = at + selected.length;
                to = block.length;
                for (let i = selEnd; i < block.length; i++) {
                  if (isEnd(block[i])) { to = i + 1; break; }
                }
              }
              const sentence = block
                .slice(from, to)
                .replace(/\\s+/g, " ")
                .trim();
              return sentence;
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
            // Throttle progress reporting: notifying Swift on every
            // scroll frame floods the bridge and (via progress saving)
            // stutters the scroll. ~5×/s while moving + once at rest is
            // plenty for the progress bar.
            let lastNotify = 0;
            let restTimer = null;
            window.addEventListener("scroll", () => {
              const now = performance.now();
              if (now - lastNotify >= 200) {
                lastNotify = now;
                lumen.syncScrollPage();
              }
              clearTimeout(restTimer);
              restTimer = setTimeout(() => lumen.syncScrollPage(), 160);
            }, { passive: true });
            window.addEventListener("resize", () => {
              lumen.remeasureScroll();
            });
            // Late layout settle (web fonts, images) shifts heights;
            // re-measure once things calm down.
            setTimeout(() => { lumen.remeasureScroll(); }, 350);
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

          // Horizontal page turns in paged flow are owned by the native
          // UIScrollView (isPagingEnabled): it tracks the finger and snaps
          // to columns — EXCEPT in curl mode, where Swift disables native
          // panning and the handlers below scrub the captured curl from
          // the finger instead. Chapter-edge advances ride the scroll
          // view's overscroll normally; in curl mode they arrive as an
          // "edgeDrag" message from these handlers.
          let touch = null;
          const curlDraggable = () =>
            MODE === "paged" && lumen.transition === "curl";
          document.addEventListener("touchstart", (e) => {
            if (!curlDraggable() || e.touches.length !== 1) {
              touch = null;
              return;
            }
            const t = e.touches[0];
            touch = { id: t.identifier, x: t.clientX, y: t.clientY };
          }, { passive: true });
          document.addEventListener("touchmove", (e) => {
            if (!curlDraggable() || !touch) { return; }
            let t = null;
            for (const c of e.touches) {
              if (c.identifier === touch.id) { t = c; }
            }
            if (!t) { return; }
            const dx = t.clientX - touch.x;
            const dy = t.clientY - touch.y;
            const drag = lumen.curlDrag;
            if (!drag) {
              // Horizontal intent only, and never while a turn plays or
              // the reader is adjusting a text selection.
              if (lumen.curlLive) { return; }
              if (Math.abs(dx) < 15
                  || Math.abs(dx) <= Math.abs(dy)) { return; }
              const sel = window.getSelection();
              if (sel && !sel.isCollapsed) { return; }
              lumen.curlDragBegin(dx < 0, touch.id);
              return;
            }
            if (drag.touchId !== touch.id || drag.ended) { return; }
            if (drag.edge) { drag.dx = dx; return; }
            const along = drag.forward ? -dx : dx;
            drag.progress = Math.min(1, Math.max(
              0, along / window.innerWidth
            ));
            drag.grabY = Math.min(0.95, Math.max(
              0.05, t.clientY / window.innerHeight
            ));
            if (drag.sheet) {
              drag.sheet.draw(drag.progress, drag.forward, drag.grabY);
            }
          }, { passive: true });
          const curlTouchDone = (e, cancelled) => {
            if (!touch) { return; }
            let lifted = false;
            for (const c of e.changedTouches) {
              if (c.identifier === touch.id) { lifted = true; }
            }
            if (!lifted) { return; }
            const drag = lumen.curlDrag;
            touch = null;
            if (!drag || drag.ended) { return; }
            if (drag.edge) {
              lumen.curlDrag = null;
              if (!cancelled && Math.abs(drag.dx || 0) >= 70) {
                window.webkit.messageHandlers.lumen.postMessage({
                  type: "edgeDrag", direction: drag.edge
                });
              }
              return;
            }
            if (cancelled) {
              lumen.curlDragFinish(drag, false);
              return;
            }
            // Commit rule: a flick along the turn commits regardless of
            // distance; otherwise commit past halfway.
            const speed = drag.progress * window.innerWidth
              / Math.max(1, performance.now() - drag.t0);
            lumen.curlDragFinish(
              drag, speed > 0.3 || drag.progress > 0.5
            );
          };
          document.addEventListener("touchend", (e) => {
            curlTouchDone(e, false);
          }, { passive: true });
          document.addEventListener("touchcancel", (e) => {
            curlTouchDone(e, true);
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
