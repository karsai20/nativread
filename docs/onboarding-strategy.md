# Onboarding strategy

Status: PRODUCT DIRECTION, 2026-07-02.

## Product principle

NativRead has three jobs:

1. Translate a book the user already owns.
2. Help the user read in a language they are learning.
3. Provide a calm, beautiful reader for people who simply want to read.

The first-run flow should personalize the app around those jobs, then get the user
to a book as quickly as possible. It should not start as a generic feature tour.

Market-proven language-learning onboarding patterns are consistent:

- ask the user's language or interface language first;
- ask the target language;
- ask why they are learning / what they want to do;
- ask current level or confidence;
- ask commitment only if the product has a habit loop;
- show immediate value before asking for payment or heavy permissions.

For NativRead, the habit loop is weaker than Duolingo/Babbel. The stronger loop is
"import a book, see the first useful translation/lookup, continue."

## Critical language model correction

Do not keep thinking of "Define language" as one setting.

For language learning, the language the user wants to learn is usually the
language of the book they want to read. The helper language is the language they
already understand.

Example:

- User wants to learn Spanish.
- User reads Spanish books.
- Useful dictionary pack is Spanish -> English or Spanish -> Hungarian.
- English -> Spanish is not the main learner lookup path.

So the product model should split:

- App language: UI language.
- Native/helper language: language used for explanations, onboarding and glosses.
- Learning language: language of books the user wants to read to learn.
- Translation target language: language a full book should be translated into.
- Dictionary pack: a pair, `bookLanguage -> helperLanguage`, not just one
  language toggle.

The current multi-Define work is useful plumbing, but the naming and onboarding
should move away from "Define languages" before launch.

## Recommended first-run flow

### 1. App language

Question: "Choose your app language"

Options:

- System default, preselected.
- English.
- Magyar.

Rules:

- This is only UI language.
- Keep it fast and plain.
- Do not mix it with "what language are you learning?"
- Add a small "Change later in Settings" line.

Why first:

- It reduces confusion for non-English users.
- It matches the user's instinct: first make the app understandable.

### 2. One-screen product promise

Purpose: show what the app does before asking intent questions.

Content:

- A real reader preview, not a marketing hero.
- A selected sentence with two visible actions:
  - Translate chapter.
  - Define word.
- One short line: "Read your own books with translation and word help."

Do not list every feature. This screen should establish the mental model:
"I bring a book; NativRead helps me read it."

### 3. Primary use

Question: "What do you want to use NativRead for?"

Options:

- Translate books I own.
- Learn a language by reading.
- Both.
- Just read my books.

Effects:

- Translate books: prioritize import/attestation/free chapter.
- Learn language: prioritize learning language + helper language + dictionary
  pack.
- Both: ask both, but default to translation path after setup.
- Just read: prioritize book import, reading theme, typography and a clean
  library. Do not show paid translation prompts during onboarding.

This mirrors proven app onboarding where intent drives personalization, but keeps
the answer practical rather than personality-style.

### 4. Language goal

Branch A: Translate books

Question: "What language do you want books translated into?"

Launch behavior:

- Show Hungarian as available.
- Show other strong market languages as "planned" only if we want demand capture.
- Do not promise French/Spanish/German translation until the quality pipeline
  passes them.

Branch B: Learn by reading

Question: "What language do you want to read?"

Recommended visible options for the first serious version:

- English.
- Spanish.
- German.
- Italian.

Rules:

- Only show a language if there is a strong dictionary path or a planned
  downloadable pack.
- If a user picks Spanish/German/Italian, the app must download or offer the
  correct `Spanish/German/Italian -> helper` pack, not English -> target.

### 5. Helper language

Question: "What language should explanations use?"

Default:

- Same as app language, if supported.
- Otherwise English.

Purpose:

- Defines dictionary direction.
- Defines translation output for learner explanations.
- Later can drive AI explanation prompts.

### 6. Current level

Question: "How comfortable are you reading in [learning language]?"

Options:

- Beginner.
- Some basics.
- Comfortable with help.
- Advanced.

Use:

- Beginner: suggest Translate-first or easier samples.
- Some basics: enable frequent Define, vocabulary capture.
- Comfortable: lighter hints, less onboarding copy.
- Advanced: dictionary stays available but quiet.

Do not make this a CEFR exam in first run. If needed later, add a placement test
after the user has imported a book.

### 7. Offline packs

Screen: "Install reading help"

Show only packs needed for the chosen path:

- English definitions: included.
- Hungarian helper for English books: included or small download.
- Spanish/German/Italian learner packs: download on demand when real packs exist.

Each row:

- Language pair, for example "Spanish -> English".
- Source/quality label, for example "FreeDict, strong" or "Beta".
- Download size.
- Installed / Install / Remove.

No long list. No unavailable languages in the main list.

### 8. Book import

Primary CTA depends on intent:

- Translate path: "Choose a book to translate".
- Learning path: "Choose a book to read".
- Both: "Choose your first book".
- Just read: "Add your first book".

If translation path:

- ownership attestation appears per book, not buried in onboarding.
- first chapter translation starts after upload.

If learning path:

- open the reader quickly and teach selection via the actual word-selection UI.

If just-read path:

- open the imported book immediately;
- show one compact appearance step only if it helps the aesthetic promise
  ("Choose your reading atmosphere");
- keep Define/Translate discoverable in reader menus, but do not interrupt the
  first reading session with upsell copy.

### 9. Notification permission

Ask only after a translation job starts.

Copy:

- "We'll notify you when your translated book is ready."

Do not ask during generic onboarding. Apple guidance and normal mobile practice
favor asking permissions in context, when the value is visible.

### 10. Payment

Never ask during generic onboarding.

Ask after:

- free first chapter is visible, or
- the user explicitly taps Translate whole book.

This keeps onboarding from becoming a paywall and lets the first-run value do the
selling.

## First-run variants

### New user, translation intent

1. App language.
2. Product promise.
3. Primary use: Translate books.
4. Translation target: Hungarian available.
5. Choose book.
6. Ownership attestation.
7. Free first chapter.
8. Contextual purchase prompt.

### New user, language-learning intent

1. App language.
2. Product promise.
3. Primary use: Learn by reading.
4. Learning language.
5. Helper language.
6. Level.
7. Install required reading-help pack.
8. Choose book.
9. Reader opens, selection affordance teaches Define.

### New user, just-reading intent

1. App language.
2. Product promise.
3. Primary use: Just read my books.
4. Optional reading atmosphere preview.
5. Add first book.
6. Reader opens immediately.
7. Translation and Define stay available as quiet secondary actions.

### Returning user / reinstall

1. Restore language from settings.
2. Restore packs and library.
3. Skip onboarding.
4. If state is incomplete, resume from the next missing decision.

## Settings redesign

Rename Settings section to "Languages & Packs".

Sections:

- App language.
- Translation target.
- Learning language.
- Helper language.
- Installed packs.
- Available strong packs.
- Reading appearance.

Pack row:

- Pair: `Spanish -> English`.
- Purpose: "Word lookup while reading Spanish".
- Size.
- Source/quality.
- Remove button.

Avoid:

- "Define language" as a label.
- Showing unsupported languages.
- Treating UI language changes as automatic learning-language changes after the
  user has made explicit choices.

## Reader UI consequence

Book translation must get the primary UI position:

- Library/book detail primary CTA: Translate book / Continue translation.
- Reader selected-text menu primary action for whole-book users: Translate
  chapter or View translation.
- Define remains in the selected-word menu and vocabulary flow.

The app should feel like a reading app with a translation engine, not a dictionary
app with an extra translation button.

## Define direction

Use the iOS built-in Dictionary experience as the primary Define surface.
KyBook's strongest lookup behavior comes from this system layer: the user gets
Apple's installed dictionaries, the native definition UI, and the system Manage
Dictionaries flow instead of a small app-maintained dictionary picker.

Product consequence:

- Reader selected text -> Define opens the native Apple Dictionary sheet.
- Do not position bundled StarDict dictionaries as the main reader lookup UI.
- Keep app-owned dictionaries only where the app needs machine-readable glosses:
  saved vocabulary, export, tests, and offline fallback.
- Rename settings/copy away from "Define language"; the user-facing concept is
  "Explain words in..." or "Reading help", not dictionary administration.

Technical constraint:

`UIReferenceLibraryViewController` displays system dictionary definitions but does
not expose the definition text back to the app. Saving a word to vocabulary must
therefore either save a bundled/offline gloss, save only the word + context, or
offer a separate manual note path. Do not promise Anki/export quality from the
system dictionary text unless a separate licensed dictionary source supplies it.

For just-read users, the reader itself is the product:

- Library/book detail primary CTA: Read.
- Reader chrome prioritizes typography, contents, search and highlights.
- Translate book is visible but secondary, for example in book actions or a
  contextual banner after the user has opened the translation tools.
- No persistent purchase CTA on books where the user has not shown translation
  intent.

## Copy direction

Plain labels:

- "App language"
- "I want to translate books"
- "I want to learn by reading"
- "I just want a beautiful reader"
- "Books I read are in..."
- "Explain words in..."
- "Install reading help"
- "Translate my first chapter"
- "Add my first book"
- "Choose your reading atmosphere"

Avoid:

- "Define language"
- "Target language" without context
- "Multilingual dictionary"
- "Personalized AI-powered learning journey"

## Telemetry needed

To validate the onboarding:

- onboarding_started
- app_language_selected
- primary_use_selected
- reading_appearance_selected
- translation_target_selected
- learning_language_selected
- helper_language_selected
- level_selected
- pack_install_started / completed / failed
- first_book_import_started / completed
- first_define_used
- free_chapter_completed
- purchase_started / completed

Segment by primary use and language pair. Do not log book text.

## Open decisions

- Whether to show planned translation languages as demand-capture waitlist rows.
  Recommendation: not in the main path; if used, put behind "Other language".
- Whether Spanish/German/Italian learner mode should launch before dictionary
  direction is corrected. Recommendation: no.
- Whether to make account login part of onboarding. Recommendation: no for
  reading/Define; yes only when translation requires paid server work.

## Sources and market references

- Apple Human Interface Guidelines, Onboarding and Launching:
  https://developer.apple.com/design/human-interface-guidelines/onboarding
  and https://developer.apple.com/design/human-interface-guidelines/launching
- Babbel onboarding pattern as summarized in TechRadar: Babbel asks why the user
  wants to learn, whether they know the language, and how much time they can
  commit before the course begins:
  https://www.techradar.com/best/best-language-learning-apps
- Duolingo 2025 course expansion: the seven most popular non-English languages
  were Spanish, French, German, Italian, Japanese, Korean and Mandarin:
  https://www.theverge.com/news/658968/duolingo-language-courses-ai
- Busuu product model: CEFR levels, themed lessons, native-speaker/community
  practice and premium offline mode:
  https://en.wikipedia.org/wiki/Busuu
- Language pack decision and dictionary evidence:
  ./language-pack-market-research.md
