# Changelog

All notable changes to NativRead are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

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
