# Changelog

All notable changes to NativRead are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Changed
- Before the first AI translation, NativRead now clearly names Google Gemini API, explains exactly what book data leaves the device and for how long, and asks for separate, versioned permission. Declining keeps the offline reader fully usable.
- Settings now includes an in-app Privacy Policy and a permanent account-deletion flow. Deletion reconfirms and revokes Sign in with Apple, removes server-side translation data and entitlements, and leaves books stored on the device untouched.
- The translation sheet now leads with the book, target language, and free first chapter. Sign in appears only after accepting the versioned, readable Terms of Use, while optional process details and developer-only whole-book controls stay collapsed.
- First launch now detects the iPhone language and asks for confirmation directly on the animated welcome—there is no separate language screen. The user-paced three-step guide explains adding, translating, and comfortably reading a book, with large controls, landscape layouts, and Reduce Motion support.
- Word lookup now uses the native iOS **Look Up** action exclusively. The custom Define sheet, saved vocabulary, and vocabulary exports were removed.
- Reading streaks and statistics were removed so the app stays focused on translating and reading.
- First launch now states the core promise — **Your books. In your language.** — and an empty shelf shows one clear Add a book action instead of duplicate import controls.
- App chrome now scales with Dynamic Type, key controls meet the 44-point target, Reduce Motion/Reduce Transparency are respected, and reader controls expose clearer VoiceOver actions.

### Fixed
- Rotating into landscape rebuilds EPUB pagination for the new viewport while preserving the chapter position, instead of keeping portrait-width columns and drifting out of alignment.
- Relaunching the app no longer marks an active backend translation as interrupted. NativRead reconnects to the saved backend job, downloads the finished EPUB, and imports it automatically.

## [3.4] - 2026-07-13

### Added
- Three new page-turn styles join Slide: **Curl** — the classic book-like page fold known from Apple Books — plus **Fade** and **None** (instant), so every reading taste from skeuomorphic to speed-reading is covered.
- In Curl mode you can now **drag the page with your finger**: the sheet bends and follows your touch, a flick or pulling past halfway commits the turn, and letting go settles the page back down.

### Changed
- The Curl turn was rebuilt so the new page emerges live under the lifting sheet — no flash of the old page, and the sheet's underside matches your theme's paper colour in dark and sepia too.
- Page turning in paged mode follows your finger exactly, tap-turns settle with a soft glide, and pulling past a chapter's edge turns into the next or previous chapter.
- The E-ink transition is now **Fade**: instead of a black flash, the page dissolves gently through the paper colour — in dark themes too. Your saved transition setting carries over automatically.
- Settings has a full editorial redesign: page-like appearance tiles (System / Light / Dark), grouped language sections, a serif header, and a quieter power-user area.
- Scrolling in vertical (scroll) reading mode is noticeably smoother.

### Fixed
- The Define sheet's dictionary no longer opens blank or choppy — the definition appears as soon as the sheet settles.
- Rapid taps and drags no longer fight the page-turn animation, skip pages, or bounce back mid-turn; interrupted turns (an incoming call, switching apps) always land on the right page.
- Pulling hard past a chapter's edge can no longer save your reading position against the wrong chapter.

## [3.3] - 2026-07-09

### Added
- Choose the translation language for each book before translating. The picker only offers languages that passed our literary quality bar — more are coming as each one clears it.
- Pick your Define dictionary language in Settings: English uses the built-in glossary, Magyar adds English → Hungarian lookup, and the Apple system dictionary stays available as a fallback below every definition.
- Settings → About shows the app version and an open-source Licenses page.
- Every AI-translated book delivered from now on carries a machine-readable "AI-generated" marker and a colophon page, in line with the EU AI Act — the marker survives export to your other devices.

### Changed
- After you finish your first AI-translated book (or your third book overall), the app may ask once — and only once — how you like it. Never after an error.

## [3.2.1] - 2026-07-07

### Changed
- AI-translated books are now clearly labeled as AI throughout the app: library badges read "AI · HU", translated copies are titled "(AI Hungarian translation)" / "(AI Hungarian preview)", and the translation sheet confirmation says so too — so you always know which books were machine-translated (EU AI Act transparency).

### Fixed
- Books translated before this update are relabeled automatically, so older translated copies in your library get the same AI marking as new ones.

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
- The app now uses the **NativRead** name, icon, and identity throughout.
- New editorial design system: Charter serif typography and the Paper (Light) / Ink (Dark) reading themes.
- Cleaner reading chrome and more consistent typography across the library and reader.

### Fixed
- Switching the interface language now refreshes the library and its sheets live, without restarting.
