# Reading atmospheres (8 themes) + appearance panel redesign

Date: 2026-09-14 · Status: approved direction, spec for review
Decision brief (visual): https://claude.ai/code/artifact/717cdeef-6906-48f3-8762-fc902ad79f26

## Goal

Give readers the eight reading atmospheres competitors have converged on
(Kindle: white/sepia/sage/black; Apple Books: Original/Quiet/Paper/Bold/
Calm/Focus) plus the two most-requested gaps (true OLED black, warm amber
night), and replace the three-tab "Aa" sheet with a single scrolling panel
whose theme tiles preview the real font and colours. Typography on the page
gets the size-specific tracking/leading and optical sizing the current CSS
lacks.

Out of scope: chrome/menu redesign, page-turn motion, PDF reader (keeps its
own 3-theme picker), custom colour picker.

## 1. Themes — `ReaderTheme`

Order is the order of the tiles: light row first, dark row second.

| case  | label key / EN     | background | text    | accent  | isDark | text CR | note |
|-------|--------------------|------------|---------|---------|--------|---------|------|
| paper | theme.label.paper "Light"     | #F5F1E8 | #2B2A26 | #6F7E68 | no  | 12.7 | existing |
| sepia | theme.label.sepia "Sepia"     | #F1E6CF | #3B3020 | #6E7A5F | no  | 10.4 | existing |
| mist  | theme.label.mist  "Mist"      | #E3EAE0 | #25312A | #4E6B58 | no  | 11.0 | new — sage green (Kindle "light green") |
| bold  | theme.label.bold  "Bold"      | #FBFAF7 | #141311 | #8A2F22 | no  | 17.8 | new — high contrast, body weight 500 |
| dusk  | theme.label.dusk  "Dusk"      | #21252B | #CBCED4 | #A6B49E | yes | 9.8  | existing |
| amber | theme.label.amber "Amber"     | #2A1F16 | #E6CFAE | #D2A263 | yes | 10.6 | new — lowest blue light |
| ink   | theme.label.ink   "Dark"      | #181A18 | #E7E3D8 | #A6B49E | yes | 13.7 | existing |
| night | theme.label.night "Night"     | #000000 | #CFC9BC | #C39A68 | yes | 12.7 | new — true OLED black |

- Secondary text, surface, surfaceRaised, hairline derive from the existing
  `blendHex` rules; secondaryTextHex gets an explicit value per new case
  (mist #5C6B60, bold #55524C, amber #A8906E, night #8F8A80).
- `shadowOpacity`: mist 0.10, bold 0.10, amber 0.34, night 0.42.
- `ReaderTheme.bodyFontWeight: Int` — 500 for `bold`, 400 otherwise. Emitted
  in `ReaderStyle.css` as `font-weight` on `body`. Variable faces (Crimson
  Pro, Cormorant, New York/ui-serif, San Francisco) render a true medium;
  static faces (Charter, Georgia, Palatino) resolve 500 → regular per CSS
  font matching, so Bold there is contrast-only. Known ceiling, accepted.
- Decoding: `ReaderTheme` is `Codable` by rawValue; old libraries only ever
  stored the four existing cases, so no migration.
- Localizable.xcstrings: 4 new keys × existing locales (EN/HU/DE/ES), plus
  `-forceTheme` in `NativReadApp` already accepts any rawValue.

## 2. Appearance panel — `TypographyPanel`

Hybrid of directions A and C from the brief: **theme tiles in two rows (C),
everything else as one scrolling list without tabs (A).**

```
┌ grabber ─────────────────────────────┐
│ ATMOSPHERE                            │
│ [Aa][Aa][Aa][Aa]   ← light row        │
│ [Aa][Aa][Aa][Aa]   ← dark row         │
│ ○ Match system appearance             │
│ ───────────────────────────────────── │
│ TEXT                                  │
│ Text size        [ A ][ Aa 18 ][ A ]  │
│ Typeface                  Charter  ›  │  → inline expands to the font list
│ Line spacing     ──────●───   1.45    │
│ ○ Justify text                        │
│ ───────────────────────────────────── │
│ LAYOUT                                │
│ Margins          ───●──────   20 pt   │
│ Page flow        [ Pages | Scroll ]   │
│ Page turn        [Slide|Curl|Fade|None]│  (paged only; reduce-motion row as today)
│ ○ Two-page spread                     │  (regular width only)
│ ───────────────────────────────────── │
│ COMFORT                               │
│ Warm light       ☾ ──●──────── ☀ 0%   │
│ Brightness       ☀ ─────●──── ☀ 50%   │
└──────────────────────────────────────┘
```

- Detents stay `[.height(450), .large]`; the 450 detent shows the two tile
  rows, the system toggle and the Text size stepper — the three things a
  reader touches most — without scrolling.
- `ThemeTile` renders "Aa" in the **currently selected reader font** (via the
  UIFont for `ReaderFont`, falling back to the display face for system
  faces) and shows the theme label under it; selected tile keeps the accent
  ring. Tile height 58 → 64 so the label and ring read at 4-up on 393 pt.
- Tile grid: `LazyVGrid` with 4 flexible columns; order = `ReaderTheme.allCases`.
- Typeface row is a disclosure: collapsed shows the current name; tapping
  expands the existing `fontList` inline (each name in its own face, as now).
  Expanded state is `@State`, not persisted.
- `SegmentedTabs` and `AppearanceTab` are deleted; the `-appearanceTab`
  launch argument goes away with them (only used by screenshot tests).
- Section eyebrows use `Typography.eyebrow` with `.kerning(0.06em-equivalent)`;
  the accessibility identifiers of every control are unchanged
  (`theme.<case>`, `font.<case>`, `flow.<case>`, `transition.<case>`,
  `theme.auto`, `layout.spread`, `layout.allowsMotion`, `comfort.warmth`,
  `comfort.brightness`).

## 3. Typography foundations — `ReaderStyle.css`

Added to every theme's CSS:

```css
html { font-optical-sizing: auto; }
body { font-weight: <theme.bodyFontWeight>; letter-spacing: 0; }
h1, h2, h3 { letter-spacing: -0.01em; line-height: 1.2 !important; }
h4, h5, h6 { letter-spacing: 0;        line-height: 1.25 !important; }
small, .small-caps, [style*="small-caps"] { letter-spacing: 0.04em; }
```

Dynamic Type as the starting size: `ReaderSettings.fontSize` default becomes
`ReaderSettings.defaultFontSize(for: UIApplication.shared.preferredContentSizeCategory)`
— mapping L→18 (unchanged default), XL→19, XXL→20, XXXL→22, AX1+→24,
S/XS→16/15. Applied only when no stored settings exist (first launch); a
saved size always wins. The reader chrome labels already use the token
scale and are not changed.

## 4. Files

- `NativRead/Models/ReaderSettings.swift` — 4 cases, colours, `bodyFontWeight`, default size mapping.
- `NativRead/Services/ReaderStyle.swift` — weight + tracking/leading + optical sizing.
- `NativRead/Views/Reader/TypographyPanel.swift` — rewrite body: sections, no tabs, disclosure typeface row.
- `NativRead/Views/Reader/ReaderAppearanceControls.swift` — `ThemeTile` font preview; delete `SegmentedTabs`/`AppearanceTab`.
- `NativRead/Resources/Localizable.xcstrings` — theme labels, section eyebrows.
- `NativRead/NativReadApp.swift` — drop `-appearanceTab` if referenced.
- Tests: `NativReadTests/ModelTests.swift` (new cases encode/decode, CSS
  contains weight 500 only for bold, default size mapping),
  `NativReadUITests/ReaderJourneyUITests.swift` (theme picker shows 8 tiles,
  selecting `theme.night` recolours; `openLayoutTab` helper → scroll-to-row),
  `AppShowcaseScreenshotUITests` (`-appearanceTab` removal).

## 5. Acceptance

- All 8 tiles visible in the 450 pt detent on iPhone 17 Pro; selecting any
  recolours the page live; relaunch restores it.
- Bold renders visibly heavier body text than Paper on Crimson Pro and New York.
- Unit suite green; the five existing appearance UI tests pass or are
  updated for the tab removal; no accessibility identifier renamed.
