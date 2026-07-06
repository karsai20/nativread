# Language pack and Define market research

Status: PRODUCT DIRECTION, 2026-07-02.

## Decision

Do not show every technically possible Define language. Show only languages that
clear all three gates:

1. Large likely demand for translated reading or language-learning reading.
2. Strong offline dictionary coverage that can be shipped or downloaded legally.
3. Clear product fit without stealing space from the primary book translator UI.

The book translator is the main product surface. Offline Define is a supporting
feature for language learners and should move behind optional language packs.

## Recommended launch set

Primary target language:

- Hungarian: keep as the launch translator language, per the current translator
  plan quality gate. This is not a market-size choice; it is the first validated
  quality wedge.

Strong optional Define packs:

- English: WordNet fallback and monolingual definitions. Must always be available
  as a safety net.
- Spanish: high learner demand and good FreeDict English-Spanish coverage.
- German: high learner demand, strong ebook/reader market signal, and excellent
  FreeDict English-German coverage.
- Italian: lower demand than Spanish/German but still mainstream and FreeDict
  coverage is usable.
- Russian or Arabic: consider later if we want non-EU reach; both have usable
  FreeDict coverage, but product positioning and moderation/support risk are
  higher.

Do not expose yet:

- French: demand is real, but the immediately available FreeDict English-French
  package is weak compared with Spanish/German/Italian. Add only if we build a
  Kaikki/Wiktextract or DBnary pipeline, or license paid data.
- Japanese, Korean, Chinese: demand is strong, but dictionary/lemmatization and
  tokenization are not a simple StarDict drop-in. These deserve a separate CJK
  track rather than appearing as half-working toggles.
- Portuguese: broad market, but current free English-Portuguese dictionary
  coverage is weaker than the strongest candidates.

## Source signals

Language-learning demand:

- Duolingo's broad public ranking signals English, Spanish, French, German,
  Japanese, Italian, Korean, Mandarin, Portuguese, Russian, Hindi and Arabic as
  the largest learner languages. A 2025 Duolingo course expansion also names its
  seven most popular non-English languages as Spanish, French, German, Italian,
  Japanese, Korean and Mandarin.
- Babbel's public material lists Spanish, French, Italian and German as among the
  most popular languages in the US market.
- Web content language share also supports Spanish/German/Japanese/French/
  Portuguese/Russian/Italian as large practical reading markets.

Dictionary quality:

- FreeDict has offline StarDict downloads and is a direct fit for NativRead's
  current bundled dictionary pipeline.
- Strong FreeDict headword counts: English-German about 460k, English-Hungarian
  about 90k, English-Spanish about 64k, English-Italian about 53k,
  English-Russian about 62k, English-Arabic about 87k.
- Weak or not enough for a premium-looking option: English-French about 9k,
  English-Portuguese about 16k.
- Kaikki/Wiktextract is much larger and richer, but should be processed at build
  time into a compact app format, not shipped raw.
- DBnary is useful for Wiktionary-derived translation data, but RDF/OntoLex makes
  it a build-pipeline project, not a quick bundle.

Reader product expectations:

- Built-in/offline dictionary lookup is common in established reader products:
  Kindle supports dictionary and Wikipedia lookup; Apple Books and Kindle are
  listed with offline dictionary support in iOS e-reader comparisons; Kobo
  devices support built-in dictionary lookup by long-press.
- This means offline Define is expected by serious reader users, but it is not
  the differentiator. It should be present, quiet, and reliable.

## Product implications

Onboarding should not ask "which app language?" as the main first decision.
The first decision should be the job-to-be-done:

- Translate my book.
- Read and look up words.
- Both.

Then ask:

- Translation target language: launch default Hungarian only until quality gates
  add more.
- Optional dictionary packs: show only strong packs, each with download size and
  a clear on/off state.

Settings should become "Languages & Packs":

- App language: UI language only.
- Translation language: primary paid product setting.
- Dictionary packs: downloadable/removable packs. Only installed packs live on
  the phone.
- Offline Define: a toggle per installed pack, not a global feature that implies
  every language is available.

Reader UI should reserve the prominent space for book translation:

- Primary action: Translate book / Translate next chapter / View translated copy.
- Secondary action: Define selected word.
- Vocabulary remains behind the reader/library toolbar, not in the main purchase
  path.

## Implementation notes

- Keep WordNet in every dictionary build path as a fallback so unbundled or
  removed packs never leave `DictionaryProvider.isReady == false`.
- Only expose `AppLanguage.definePickable` entries that have a real installed or
  downloadable pack.
- Add a language-pack manifest with `code`, `displayName`, `source`, `version`,
  `headwordCount`, `compressedBytes`, `installed`, and `qualityTier`.
- Do not bundle all dictionaries into the app binary. Ship English/WordNet and
  Hungarian for launch; download other strong packs on demand.

## Sources

- FreeDict home and downloads: https://freedict.org/ and
  https://freedict.org/downloads/
- FreeDict API: https://freedict.org/freedict-database.json
- Kaikki/Wiktextract English extract: https://kaikki.org/dictionary/English/
- DBnary downloads: https://kaiko.getalp.org/static/ontolex/latest/
- Lexicala paid lexical data: https://api.lexicala.com/
- Merriam-Webster API terms: https://dictionaryapi.com/
- Kindle feature summary: https://en.wikipedia.org/wiki/Amazon_Kindle
- iOS e-reader dictionary comparison:
  https://en.wikipedia.org/wiki/Comparison_of_iOS_e-reader_software
- Kobo reader feature summaries: https://en.wikipedia.org/wiki/Kobo_Aura and
  https://en.wikipedia.org/wiki/Kobo_Glo
