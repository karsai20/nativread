# TODOS

Deferred work, captured so vague intentions don't get lost.
Source: /plan-ceo-review 2026-06-22 (see design doc + CEO plan in ~/.gstack/projects/karsai20-quire/).

## Format support — MOBI/AZW3

- [x] **Pure-Swift AZW3 (KF8) → EPUB import.** DONE 2026-07-06 (commit adds
  `NativRead/EPUB/{PalmDatabase,MOBIHeader,PalmDocDecompressor,MOBIIndex,
  KF8Converter,KF8EPUBWriter}.swift`; `mobi/azw/azw3/prc` routed through
  `LibraryStore.importMOBI` → `importEPUB`). Verified end-to-end against a real
  DRM-free fixture (Alice/Tenniel). Native converter, no C dep, no LGPL.
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
- [ ] **Background URLSession for the translate pipeline.** The whole flow runs
  in a foreground `Task` from the sheet; app suspension kills it mid-request.
  Use a background `URLSession` (or reconcile-on-relaunch via the persisted
  `backendJobID` + `status()`), which also fixes the "interrupted job" story
  beyond the current fail-on-reload. **Priority:** P2.
- [ ] **Server-authoritative entitlements.** Payment/ownership are client-side
  only right now (the MVP calls the full path directly; identity is a UUID
  header over cleartext). When IAP lands, the backend must verify the receipt
  and not trust `x-nativread-user-id`; move that ID to Keychain and put the
  backend behind TLS. **Priority:** P1 for the paid phase.
- [ ] **`alreadyTranslated` result-kind mismatch.** If the backend has a *full*
  translation cached and the user asks for a *preview*, the client imports the
  full book labeled "(Hungarian preview)" at `translatedFraction = 0.01`. The
  upload response needs to say *what kind* of cached result exists. **P2.**
- [ ] **`UIReferenceLibraryViewController` Manage-Dictionaries probe is fragile.**
  `DefineView.dictionaryManagementTerm` relies on undocumented behavior; keep it
  on a per-iOS-release QA checklist. **P3.**
- [ ] **Multipart filename hardening.** `multipartBody` interpolates the file
  name into the `Content-Disposition` header unescaped. Safe today (only
  `<UUID>.epub` is ever sent) but escape/hardcode it before any caller passes a
  user-named file. **P3.**

## Post-release roadmap

- [ ] **Target-language read-aloud (TTS) — the "audiobook" play.** On-device
  Hungarian voice (`AVSpeechSynthesizer`) reads the *translated* book aloud.
  This is the strategically right audio direction (not a generic MP3/m4b
  player, which is a different product with no translation synergy): the chain
  English text → Hungarian translation → Hungarian audio runs on Quire's own
  translation engine, so it delivers a Hungarian audio version of an
  untranslated English book that no competitor can. Strong delight for the 50+
  persona who prefers listening. **Sequencing:** post-launch, once the core
  translate-and-read loop is proven. Deferred from CEO review (not first round).

## Deferred design debt

Source: /plan-design-review 2026-06-28.

- [ ] **Deep accessibility pass.** Beyond the Phase 0 floor (Dynamic Type for
  chrome + 44pt targets + contrast audit): VoiceOver reading-order/rotor for the
  reader page, reduce-transparency support, and a full a11y audit across surfaces.
  **Why:** the named reference reader is 50+; the basics ship in Phase 0 but the
  thorough pass (especially VoiceOver over the WKWebView page) is its own focused
  effort. **Depends on:** Phase 0 a11y floor landing first.

## Deferred from /plan-ceo-review 2026-06-30 (translator)

- [ ] **Multi-target-language translation.** Launch is Hungarian-only (quality
  validated only for Hungarian). Add each target language once it clears the
  Hungarian-equivalent literary quality bar (re-run the quality pipeline per
  language). **Why deferred:** shipping unvalidated quality risks a bad first
  App Store review that poisons the rating for everyone. **Where to start:** the
  `Translator` interface already makes target language a config change; gate each
  on the quality pipeline. **Effort:** M per language. **Priority:** P2.
- [ ] **Inline-gloss "reading-level" learner mode.** Original text with
  per-sentence tap-to-reveal translation — a middle mode between all-English and
  fully-translated, aimed at language learners (a larger market than non-readers).
  **Why deferred:** a whole second reading surface would bloat a pre-revenue MVP;
  revisit once the core translate-and-read loop proves it sells. **Effort:** L.
  **Priority:** P2. (Promoted from honorable-mention below.)

## Undecided / honorable mentions (pull in when ready)

- [ ] Editable character-name glossary for translation (keep names consistent
  across chapters; user-facing list).
- [ ] "Reading level" inline-gloss mode — original text with per-sentence
  tap-to-reveal translation, instead of full translation. Middle mode between
  all-English and all-Hungarian; ties the learner and non-reader audiences.
- [ ] Student study-pack export — annotations + saved vocab as a formatted
  study sheet / PDF (builds on existing export).

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

## Known code TODOs (pre-existing)

- [ ] Bundle an EN→ES StarDict dictionary (OFL/CC-licensed) — `DictionaryProvider.swift:28`
- [ ] Bundle an EN→DE StarDict dictionary (OFL/CC-licensed) — `DictionaryProvider.swift:32`

## Deferred localization (from /review 2026-06-28)

- [ ] **Re-enable Spanish & German in the picker.** `AppLanguage.pickable` was
  cut to `[.en, .hu]` because `Localizable.xcstrings` only had es/de at 5/105
  keys — picking them left ~95% of the app in the English fallback. The `.es`/
  `.de` enum cases and `bundled(for:)` plumbing are still wired. To ship them:
  (1) translate the String Catalog to 105/105 for es and de, (2) bundle the
  EN→ES / EN→DE dictionaries (the two TODOs above), (3) add `.es, .de` back to
  `pickable` and update `LocalizationStoreTests.testPickableIsFullyTranslatedLanguagesOnly`
  + `LanguageSelectionUITests`.
