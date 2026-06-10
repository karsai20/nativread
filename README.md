# LumenRead

A clean, eye-friendly EPUB reader for iPhone. Inspired by Kindle's typography.

## Features

- EPUB 2 & 3 support
- Georgia / Palatino / Charter / Times New Roman typefaces
- Light, Sepia, Dark themes
- Adjustable font size (13–24pt), line height, and margins
- Table of contents
- Reading progress saved automatically
- Swipe left/right to move between chapters
- Tap centre to show/hide navigation chrome
- Add books via Files app or the + import button

---

## Setup

### Prerequisites

```bash
brew install xcodegen
```

### 1. Generate the Xcode project

```bash
cd /Users/karsai/Projects/LumenRead
xcodegen generate
```

This creates `LumenRead.xcodeproj`.

### 2. Open in Xcode

```bash
open LumenRead.xcodeproj
```

### 3. First build

- Select your iPhone as the run destination (or a simulator)
- Press **Cmd+R**

Xcode will automatically fetch ZIPFoundation via Swift Package Manager on first build.

---

## Adding Books

**Method A – Files App**
1. Open the **Files** app on your iPhone
2. Navigate to **On My iPhone → LumenRead**
3. Paste or move any `.epub` file into this folder
4. Open LumenRead — the book will appear automatically

**Method B – Share Sheet**
Any app that can share files (Safari, Mail, iBooks, etc.) can send an EPUB to LumenRead via **Share → Open with LumenRead**.

**Method C – In-App Import**
Tap the **+** button in the top-right corner of the Library screen.

---

## Typography Settings

Tap the **Aa** button at the bottom of the reader to open the Appearance panel:

| Setting | Range |
|---------|-------|
| Theme | Light / Sepia / Dark |
| Font size | 13 – 24 pt |
| Line spacing | 1.30 – 2.20 |
| Margin | 12 – 56 pt |
| Typeface | Georgia, Palatino, Charter, Times New Roman, System |

---

## Project Structure

```
LumenRead/
├── LumenReadApp.swift          — App entry point
├── Models/
│   ├── Book.swift              — Book data model + progress
│   └── ReaderSettings.swift    — Typography settings + CSS generator
├── Services/
│   ├── EPUBParser.swift        — ZIP extraction + OPF/NCX parsing
│   └── BookStore.swift         — Library management + persistence
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift   — Book grid, import flow
│   │   └── BookCard.swift      — Cover art + generated covers
│   └── Reader/
│       ├── ReaderView.swift    — Full-screen reader, chrome, TOC
│       ├── ReaderWebView.swift — WKWebView bridge, CSS injection
│       └── TypographyPanel.swift — Appearance sheet
└── Extensions/
    └── Color+Hex.swift
```

---

## Notes

- **Bookerly** is Amazon's proprietary font and is not available on iOS. Georgia is the closest equivalent with the same warmth and legibility.
- ZIPFoundation is the only external dependency.
- Books are stored in `Documents/Books/`, extracted files in `Documents/Extracted/`. Both are private to the app.
