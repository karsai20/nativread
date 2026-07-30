# NativRead bilingual screenshot set

This directory contains a deterministic product tour in English (`en/`) and
Hungarian (`hu/`). Each language has 40 portrait PNG screenshots at
1206 × 2622 pixels.

The sequence covers onboarding, empty and populated libraries, EPUB reading,
the active rotation lock, reading position, typography, contents, bookmarks,
highlights, search, translation, AI-processing consent, settings, privacy,
terms, licenses, account deletion, dark mode, and the PDF reader.

## Showcase books

- English: Lewis Carroll, *Alice’s Adventures in Wonderland*, illustrated by
  John Tenniel — [Standard Ebooks edition](https://standardebooks.org/ebooks/lewis-carroll/alices-adventures-in-wonderland/john-tenniel)
- Hungarian: Molnár Ferenc, *A Pál-utcai fiúk: Regény kis diákok számára* —
  [Project Gutenberg edition](https://www.gutenberg.org/ebooks/69689)

Both source sites provide DRM-free downloads and their own copyright or usage
notices. Check the source notice and local law before redistributing the EPUB
files outside this project.

## Regenerating

The screenshot journey lives in
`NativReadUITests/AppShowcaseScreenshotUITests.swift`. Run either language
individually:

```sh
xcodebuild test-without-building \
  -project NativRead.xcodeproj \
  -scheme NativRead \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NativReadUITests/AppShowcaseScreenshotUITests/testEnglishCompleteShowcase \
  CODE_SIGNING_ALLOWED=NO
```

Replace `testEnglishCompleteShowcase` with
`testHungarianCompleteShowcase` for the Hungarian set. The tests overwrite the
numbered PNG files in the corresponding language directory.
