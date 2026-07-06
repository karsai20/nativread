# Changelog

All notable changes to NativRead are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [3.2] - 2026-07-06

### Added
- Translate a whole book with AI: pick a book, confirm you own it, and get a fully translated copy imported back into your library to read with all the usual themes, fonts, search, and Define. A free preview translates the opening so you can judge the quality before committing, and the price for each book is shown up front by length.
- Read your Kindle books: import `.azw3` / `.mobi` (KF8) files straight from Files and read them like any EPUB, with images, chapters, and full formatting preserved.
- Export a translated book back out to a standard `.epub` you can keep or move to another reader.

### Changed
- Streamlined the Define panel to the essentials — save a word and move on, without the extra dictionary-management detour.

### Fixed
- Corrupt, DRM-protected, or unsupported Kindle files now fail import with a clear message instead of crashing or hanging the app.
- Closed several ways malicious book content could smuggle executable links or markup past the reader's sanitizer (character-escaped addresses, unquoted and form-submit attributes, embedded-frame content, and non-UTF-8 chapters).
- The app now reacts immediately when the translator backend rejects a job, instead of waiting for a timeout.

## [3.1] - 2026-06-30

### Added
- Open PDFs: import any PDF from Files and read it in a fixed-layout reader with tap-zone paging, a page scrubber, bookmarks, contents (PDF outline), full-document search, and Define on selected text.
- Open plain-text files: import a `.txt` and read it in the same reflowable reader as EPUBs, with all themes, fonts, search, and Define.
- Dark themes invert PDF pages while preserving image hues, so night reading stays comfortable without negative-looking photos.

### Fixed
- PDF reading position now saves when you turn pages by tapping, the scrubber, search, or the contents list — previously only manual swipes were remembered.
- Password-protected or unreadable PDFs are now rejected on import with a clear error instead of being added as a blank, unopenable book.

## [3.0] - 2026-06-30

### Added
- Read the app in your language: full English and Magyar (Hungarian) interface localization.
- Language selection on first launch — pick your language right after the splash; the choice sticks across launches.
- Settings screen with app appearance (Light / Dark / System), interface language, and a separate dictionary (Define) language.
- Redesigned reader appearance sheet, now organized into Theme, Text, and Layout tabs for calmer, less crowded controls.

### Changed
- The app is now **NativRead** (formerly Quire) — new name, icon, and identity throughout.
- New editorial design system: Charter serif typography and the Paper (Light) / Ink (Dark) reading themes.
- Cleaner reading chrome and more consistent typography across the library and reader.

### Fixed
- Switching the interface language now refreshes the library and its sheets live, without restarting.
