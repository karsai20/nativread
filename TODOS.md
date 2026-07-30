# TODOS

Deferred work, captured so vague intentions don't get lost.
Source: /plan-ceo-review 2026-06-22 (see design doc + CEO plan in ~/.gstack/projects/karsai20-nativread/).

## Legal & compliance (EU AI Act + licensing)

Source: /ship 2026-07-06 compliance pass. GDPR, copyright, and App Store
posture live in `docs/legal-posture.md`; these are the buildable gaps.

- [x] **EU AI Act Art 50(2) — machine-readable AI marking.** DONE 2026-07-09
  (E1+E2): backend injects IPTC `DigitalSourceType = trainedAlgorithmicMedia`
  via the OPF prefix mechanism + `dc:description` marker + colophon spine page
  into every delivered EPUB (full and sample), idempotent, fails loudly.
  Pinned spec recorded in `docs/blueprint.md` §5; validation in
  `nativread-translator/test/ai-marker.test.ts`; iOS import regression in
  `EPUBParserTests.testParsesArt50AIMarkedEPUB`.
- [x] **Explicit "AI-translated" user-facing label.** DONE 2026-07-06 —
  imported translations now read "(AI Hungarian preview)" / "(AI Hungarian
  translation)" and the library badge is "AI · HU"; marks *AI*, not just
  language (EU AI Act Art 50 visible-transparency floor). The pre-translation
  disclosure is now a separate, versioned permission shown before third-party
  AI processing; the backend also rejects missing, stale, or provider-
  mismatched permission. **Completed:** 2026-07-20.
  v3.2.1 follow-up: translation-sheet copy also says "AI", and titles of
  variants imported before the labels are migrated on load.
- [x] **OSS acknowledgements screen.** DONE 2026-07-09 — Settings → About
  (version + Licenses link) → `LicensesView` ships the full ZIPFoundation MIT
  text in-app.
- [ ] **Counsel sign-off before commercial launch.** legal-posture.md is agent
  review, not legal advice; pressure-test the personal-use-derivative position
  (operator-stores-the-copy fact pattern). **Priority:** P1 (external gate).

## Reader

Source: /ship 2026-07-12 adversarial review (Codex) on feat/reader-polish.

- [x] **Paged-mode relayout on viewport size change.** The WKWebView container
  now reports its real laid-out bounds; rotation rebuilds the fixed-width
  engine/CSS and reloads the current chapter at the same fractional position.
  Portrait plus both landscape orientations are declared in the app manifest,
  and the existing portrait-lock control remains available. **Completed:**
  2026-07-20.

## Branding

- [x] **Use NativRead consistently in current product copy and documentation.**
  The app, active website, Cloudflare URLs and current project map now use the
  same public name. **Completed:** 2026-07-22.

## Format support — MOBI/AZW3

- [ ] **Legacy `.mobi` (HUFF/CDIC) decompression.** The current converter
  handles KF8/PalmDOC (all modern AZW3 + most .mobi). Pre-2011 HUFF/CDIC-
  compressed .mobi files are not yet supported (the PalmDoc path only handles
  compression types 1/2, not 17480). Add a HUFF/CDIC decoder if such files show
  up in practice. **Priority:** P3 (rare for the target audience).

## Translator MVP — deferred from /review 2026-07-05

- [ ] **Streamed upload/download for large EPUBs.** `TranslationBackendClient`
  currently holds the whole EPUB in memory (`Data(contentsOf:)` + a second
  multipart copy) and buffers the whole translated result via `session.data`.
  A 200MB+ image-heavy book can jetsam mid-job. Move to
  `session.upload(for:fromFile:)` with a streamed multipart temp file and
  `session.download(for:)` to disk; add a size ceiling on download/unzip
  (decompression-bomb guard). **Priority:** P2 (P1 before wide distribution).
- [x] **Reconnect to durable backend translation jobs after relaunch.** Once
  upload/start returns a backend job ID, the app now preserves that ID and the
  request kind across termination. On launch/foreground it polls `status()`,
  downloads a completed result, and imports it automatically. Only an upload
  that ended before receiving a backend ID remains retry-only. A background
  URLSession is unnecessary for the long translation itself because that work
  runs on the backend. **Completed:** 2026-07-20.
- [ ] **Server-authoritative entitlements.** Payment/ownership are client-side
  only right now (the MVP calls the full path directly; identity is a UUID
  header over cleartext). When IAP lands, the backend must verify the receipt
  and not trust `x-nativread-user-id`; move that ID to Keychain and put the
  backend behind TLS. **Priority:** P1 for the paid phase.
- [ ] **`alreadyTranslated` result-kind mismatch.** If the backend has a *full*
  translation cached and the user asks for a *preview*, the client imports the
  full book labeled "(Hungarian preview)" at `translatedFraction = 0.01`. The
  upload response needs to say *what kind* of cached result exists. **P2.**
  *(Codex adversarial 2026-07-09 additions: the cache key must also carry
  `targetLanguage` — upload responds `alreadyTranslated` before `start` ever
  sends the language, so a second launch language could import the wrong-
  language cache; and `TranslationStore` keys jobs by `bookID` only, so
  `previewCompletedAt`/`fullCompletedAt` from one language block requests in
  another. Both are gated-off today because the picker only offers HU; fix
  both before language #2 goes live.)*
- [ ] **Language detection runs on the main thread.** `TranslationSheet
  .onAppear` → `LibraryStore.languageDetectionSample` reads user-controlled
  EPUB chapter files synchronously (`String(contentsOf:)`) before capping to
  4,000 chars; a huge chapter can freeze the UI when the sheet opens. Move
  the read into a background task and cap bytes-read, not decoded chars.
  Found by Codex adversarial 2026-07-09. **P2.**
- [ ] **Multipart filename hardening.** `multipartBody` interpolates the file
  name into the `Content-Disposition` header unescaped. Safe today (only
  `<UUID>.epub` is ever sent) but escape/hardcode it before any caller passes a
  user-named file. **P3.**

## Post-release roadmap

- [ ] **Target-language read-aloud (TTS) — the "audiobook" play.** On-device
  Hungarian voice (`AVSpeechSynthesizer`) reads the *translated* book aloud.
  This is the strategically right audio direction (not a generic MP3/m4b
  player, which is a different product with no translation synergy): the chain
  English text → Hungarian translation → Hungarian audio runs on NativRead's own
  translation engine, so it delivers a Hungarian audio version of an
  untranslated English book that no competitor can. Strong delight for the 50+
  persona who prefers listening. **Sequencing:** post-launch, once the core
  translate-and-read loop is proven. Deferred from CEO review (not first round).

- [ ] **Server-driven launch-language list.** Replace the hardcoded in-app
  passed-languages array (eng review D7, 2026-07-07) with a tiny backend-served
  list + bundled fallback, so a new language can launch — or a language with a
  live quality incident can be *pulled* — without an App Review cycle.
  **Why:** the hardcoded list's named ceiling; the remote-pull case is the
  non-obvious half of the rationale. **Where to start:** one GET endpoint +
  cached fallback to the bundled array; picker and waitlist options read the
  same source. **Depends on:** language #4 shipping, or a live quality
  incident. **Priority:** P3.

## Deferred design debt

Source: /plan-design-review 2026-06-28.

- [ ] **Device VoiceOver rotor verification.** The 2026-07-20 pass moved app
  typography onto Dynamic Type roles, raised key controls to 44pt, added
  Reduce Motion/Reduce Transparency handling, escape actions, and stateful
  bookmark/rotation labels. The remaining non-automatable launch check is a
  real-device VoiceOver reading-order/rotor pass over WKWebView and PDFKit text.
  **Priority:** P1 before public launch because the primary persona is 50+.

## Deferred from /plan-ceo-review 2026-06-30 (translator)

- [ ] **Multi-target-language translation.** **[PARTIALLY SUPERSEDED 2026-07-07
  — CEO D4/C: multi-language AT launch (DE/ES candidates) with a raised
  per-language gate, see blueprint.md §3. This item now covers post-launch
  languages #4+ only.]** Add each target language once it clears the
  Hungarian-equivalent literary quality bar (re-run the quality pipeline per
  language + one native-speaker read). **Why gated:** shipping unvalidated
  quality risks a bad first App Store review that poisons the rating for
  everyone. **Where to start:** the `Translator` interface already makes target
  language a config change; gate each on the quality pipeline; pick candidates
  from the in-app waitlist counts. **Effort:** M per language. **Priority:** P2.
## Undecided / honorable mentions (pull in when ready)

- [ ] Editable character-name glossary for translation (keep names consistent
  across chapters; user-facing list).

## Deferred engineering debt

Source: /plan-eng-review 2026-06-28 (built-code review of the Phase 0 localization + editorial-redesign diff).

- [ ] **Swift-6 readiness in the localization layer.** Two spots break under
  Swift-6 strict concurrency: `Bundle.overrideKey` is a mutable `static var`
  (`BundleLanguage.swift:31`) — a hard error under Swift 6 — and `@Observable`
  `LocalizationStore` mutates process-global `Bundle.main` via `object_setClass`
  without `@MainActor` isolation, a data race once strict concurrency is on.
  **Why:** compiles fine on Swift 5.9 today (`project.yml:31`), but it's a
  guaranteed build break plus a real data race the day the language version is
  bumped. **Where to start:** make `overrideKey` a non-mutable holder (e.g.
  a `let` token or `Bundle`-scoped associated-object key) and mark
  `LocalizationStore` `@MainActor`. **Depends on:** nothing now; do it as part
  of (or just before) a Swift-6 migration.

## Deferred from /ship 2026-06-30 (PDF/TXT support)

Source: adversarial/red-team review of the PDF/TXT diff. Both informational — the
common import paths are covered; these are edge-case robustness for TXT.

- [ ] **TXT line-ending + BOM normalization.** `TextImporter` splits paragraphs on
  `\n\n`/`\r\n\r\n` and collapses `\n`/`\r\n` to `<br/>`, but a lone `\r`
  (classic-Mac) is neither, and a leading UTF-8 BOM (U+FEFF) leaks into the title
  and first paragraph. **Fix:** normalize all newlines to `\n` and strip a leading
  BOM in `TextImporter.makeBook`/`render` (`TextImporter.swift:19,70`). **Priority:** P3.
- [ ] **TXT import size guard.** `Data(contentsOf:)` + the escape/split chain make
  several full-size copies on the main import path, and a file with no blank lines
  becomes one enormous `<p>` for WKWebView to lay out — a very large `.txt` (tens of
  MB) can spike memory or hang. **Fix:** cap or chunk imported text above a few MB
  (`TextImporter.swift:19`). Needs a threshold decision. **Priority:** P2.

## Deferred localization (from /review 2026-06-28)

- [ ] **Re-enable Spanish & German in the picker.** `AppLanguage.pickable` was
  cut to `[.en, .hu]` because `Localizable.xcstrings` only had es/de at 5/105
  keys — picking them left ~95% of the app in the English fallback. The `.es`/
  `.de` enum cases and `bundled(for:)` plumbing are still wired. To ship them:
  (1) translate the String Catalog completely for es and de, (2) add `.es, .de` back to
  `pickable` and update `LocalizationStoreTests.testPickableIsFullyTranslatedLanguagesOnly`
  + `LanguageSelectionUITests`.

## Completed

- [x] **Curl overlay proper view-controller containment.** Obsolete by
  design change: the curl no longer uses a `UIPageViewController` subview —
  it renders as a WebGL overlay inside the page itself (Readest-style
  captured turn), so there is no UIKit containment to forward.
  **Completed:** v3.4 (2026-07-13).
- [x] **Pure-Swift AZW3 (KF8) → EPUB import.** `NativRead/EPUB/{PalmDatabase,
  MOBIHeader,PalmDocDecompressor,MOBIIndex,KF8Converter,KF8EPUBWriter}.swift`;
  `mobi/azw/azw3/prc` routed through `LibraryStore.importMOBI` → `importEPUB`.
  Verified end-to-end against a real DRM-free fixture (Alice/Tenniel). Native
  converter, no C dep, no LGPL. **Completed:** translator-mvp branch (2026-07-06).
- [x] **GPL dictionary blocker resolved by removal.** Bundled FreeDict/StarDict
  data and the custom Define/Vocabulary feature were deleted. Word lookup now
  stays inside Apple's native Look Up action, so no GPL dictionary ships.
  **Completed:** 2026-07-20.
