# TODOS

Deferred work, captured so vague intentions don't get lost.
Source: /plan-ceo-review 2026-06-22 (see design doc + CEO plan in ~/.gstack/projects/karsai20-quire/).

## Deferred features

- [ ] **Target-language read-aloud (TTS).** On-device Hungarian voice
  (`AVSpeechSynthesizer`) reads the translated book aloud. Strong delight for the
  50+ persona who may prefer listening. Deferred from the CEO review (not first round).

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
