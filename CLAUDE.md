# NativRead (product: Quire)

Calm, editorial EPUB (+PDF/TXT) reader for iOS 17+. SwiftUI + `@Observable`, Swift 5.9, only external package: ZIPFoundation. Flagship bets: free AI translation for non-English readers (backend: `../quire-translator`) and reading tools for the 50+ Hungarian persona.

## Commands

```bash
xcodegen generate   # after adding/removing files or editing project.yml
xcodebuild test -project NativRead.xcodeproj -scheme NativRead \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

`project.yml` is the source of truth — never hand-edit the `.xcodeproj`.

## Architecture

- `NativRead/{Models, Views, Services, EPUB, DesignSystem, Resources}` — organized by layer.
- `DesignSystem/` (`BrandPalette`, `PaletteColors`, `Typography`, `Spacing`) — all colors/fonts/spacing come from these tokens; never hardcode in views.
- Reader = per-book scoped WKWebView; EPUB HTML is sanitized (script strip + JS escaping) before injection. Keep that path intact for any new content injection.

## Gotchas

- **In-app language switch:** SwiftUI `\.locale` does NOT localize `Text`/`String(localized:)`. It works via the `Bundle.main` swizzle in `Services/BundleLanguage.swift` — route any new localization through it.
- App is fully offline **except** the translator; translator requests are scoped by install id.
- Define/dictionary has a separate target-language setting from the UI language.

## Design direction

Editorial / literary-modern: warm paper + russet accents. The earlier dark-academia direction is retired — don't reintroduce it. Design docs and competitor research: `docs/`. Deferred work: `TODOS.md`.

## gstack (REQUIRED — team enforcement)

Verify before any work: `test -d ~/.claude/skills/gstack/bin && echo GSTACK_OK || echo GSTACK_MISSING`.
If missing, STOP and tell the user to install:
`git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup --team`, then restart the tool. Do not skip skills or work around missing gstack. Skill routing lives in `~/.claude/CLAUDE.md`.
