# Reading Atmospheres + Appearance Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship 8 reading themes (4 new), a tabless single-scroll "Aa" panel whose tiles preview the real font, and size-aware typography in the page CSS — every tap recolours the page live with a spring, no mode switching.

**Architecture:** `ReaderTheme` gains four cases and a `bodyFontWeight`; `ReaderStyle.css` emits the weight and size-specific tracking/leading; `TypographyPanel` becomes one `ScrollView` of four eyebrow-labelled sections (Atmosphere · Text · Layout · Comfort) reusing the existing `ThemeTile`, `SizeStepper`, `EditorialSlider`, pill/well styles. `SegmentedTabs`/`AppearanceTab` are deleted. UI-test accessibility identifiers are unchanged except the three `appearance.tab.*` buttons, which disappear.

**Tech Stack:** SwiftUI (iOS 17+), `@Observable`, XCTest + XCUITest, `xcodegen` (no new files, so no regenerate needed), `Localizable.xcstrings` (EN source + HU).

**Spec:** `docs/superpowers/specs/2026-09-14-reading-atmospheres-and-appearance-panel-design.md`

## Global Constraints

- All colours/fonts/spacing come from `DesignSystem` tokens or `ReaderPalette`; no literals in views.
- `project.yml` is the source of truth; no files are added or removed, so the `.xcodeproj` is untouched.
- Accessibility identifiers `theme.<case>`, `font.<case>`, `flow.<case>`, `transition.<case>`, `theme.auto`, `layout.spread`, `layout.allowsMotion`, `comfort.warmth`, `comfort.brightness`, `fontsize.up`, `fontsize.down` stay exactly as they are.
- Theme hexes verbatim from the spec table (§1). Localizations: EN (source) + HU only.
- Test commands (from CLAUDE.md):
  `xcodebuild test -project NativRead.xcodeproj -scheme NativRead -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:<target>/<class>/<method>`
- Commit after every task; conventional commits, English.

---

### Task 1: Four new `ReaderTheme` cases + `bodyFontWeight`

**Files:**
- Modify: `NativRead/Models/ReaderSettings.swift:5-92` (the `ReaderTheme` enum)
- Test: `NativReadTests/ModelTests.swift`

**Interfaces:**
- Produces: `ReaderTheme.mist/.bold/.amber/.night`; `ReaderTheme.allCases` order `[paper, sepia, mist, bold, dusk, amber, ink, night]`; `var bodyFontWeight: Int` (500 for `.bold`, else 400).

- [ ] **Step 1: Write the failing tests** (append inside `ModelTests`)

```swift
    func testReaderThemeHasEightCasesLightRowThenDarkRow() {
        XCTAssertEqual(
            ReaderTheme.allCases,
            [.paper, .sepia, .mist, .bold, .dusk, .amber, .ink, .night]
        )
        XCTAssertEqual(ReaderTheme.allCases.filter { !$0.isDark }.count, 4)
        XCTAssertEqual(ReaderTheme.allCases.filter(\.isDark).count, 4)
    }

    func testNewThemesUseSpecColours() {
        XCTAssertEqual(ReaderTheme.mist.backgroundHex, "#E3EAE0")
        XCTAssertEqual(ReaderTheme.mist.textHex, "#25312A")
        XCTAssertEqual(ReaderTheme.mist.accentHex, "#4E6B58")
        XCTAssertEqual(ReaderTheme.bold.backgroundHex, "#FBFAF7")
        XCTAssertEqual(ReaderTheme.bold.textHex, "#141311")
        XCTAssertEqual(ReaderTheme.bold.accentHex, "#8A2F22")
        XCTAssertEqual(ReaderTheme.amber.backgroundHex, "#2A1F16")
        XCTAssertEqual(ReaderTheme.amber.textHex, "#E6CFAE")
        XCTAssertEqual(ReaderTheme.amber.accentHex, "#D2A263")
        XCTAssertEqual(ReaderTheme.night.backgroundHex, "#000000")
        XCTAssertEqual(ReaderTheme.night.textHex, "#CFC9BC")
        XCTAssertEqual(ReaderTheme.night.accentHex, "#C39A68")
    }

    func testOnlyBoldThemeUsesMediumBodyWeight() {
        for theme in ReaderTheme.allCases {
            XCTAssertEqual(theme.bodyFontWeight, theme == .bold ? 500 : 400, "\(theme)")
        }
    }

    func testNewThemesRoundTripThroughSettingsJSON() throws {
        var settings = ReaderSettings()
        settings.theme = .bold
        settings.darkTheme = .night
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ReaderSettings.self, from: data)
        XCTAssertEqual(decoded.theme, .bold)
        XCTAssertEqual(decoded.darkTheme, .night)
    }
```

- [ ] **Step 2: Run to verify they fail**

Run: `xcodebuild test ... -only-testing:NativReadTests/ModelTests/testReaderThemeHasEightCasesLightRowThenDarkRow -only-testing:NativReadTests/ModelTests/testNewThemesUseSpecColours -only-testing:NativReadTests/ModelTests/testOnlyBoldThemeUsesMediumBodyWeight -only-testing:NativReadTests/ModelTests/testNewThemesRoundTripThroughSettingsJSON`
Expected: compile error `type 'ReaderTheme' has no member 'mist'`.

- [ ] **Step 3: Implement in `ReaderTheme`**

Replace the case line and every switch:

```swift
enum ReaderTheme: String, Codable, CaseIterable, Identifiable {
    // Tile order: the light row, then the dark row.
    case paper, sepia, mist, bold, dusk, amber, ink, night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paper: return Bundle.main.localizedString(forKey: "theme.label.paper", value: "Light", table: nil)
        case .sepia: return Bundle.main.localizedString(forKey: "theme.label.sepia", value: "Sepia", table: nil)
        case .mist:  return Bundle.main.localizedString(forKey: "theme.label.mist", value: "Mist", table: nil)
        case .bold:  return Bundle.main.localizedString(forKey: "theme.label.bold", value: "Bold", table: nil)
        case .dusk:  return Bundle.main.localizedString(forKey: "theme.label.dusk", value: "Dusk", table: nil)
        case .amber: return Bundle.main.localizedString(forKey: "theme.label.amber", value: "Amber", table: nil)
        case .ink:   return Bundle.main.localizedString(forKey: "theme.label.ink", value: "Dark", table: nil)
        case .night: return Bundle.main.localizedString(forKey: "theme.label.night", value: "Night", table: nil)
        }
    }

    // Eye-friendly set: no pure white; Night is true black for OLED, Amber
    // the lowest-blue-light page, Mist the Kindle-style sage, Bold the
    // high-contrast page for readers who need it.
    var backgroundHex: String {
        switch self {
        case .paper: return "#F5F1E8"
        case .sepia: return "#F1E6CF"
        case .mist:  return "#E3EAE0"
        case .bold:  return "#FBFAF7"
        case .dusk:  return "#21252B"
        case .amber: return "#2A1F16"
        case .ink:   return "#181A18"
        case .night: return "#000000"
        }
    }

    var textHex: String {
        switch self {
        case .paper: return "#2B2A26"
        case .sepia: return "#3B3020"
        case .mist:  return "#25312A"
        case .bold:  return "#141311"
        case .dusk:  return "#CBCED4"
        case .amber: return "#E6CFAE"
        case .ink:   return "#E7E3D8"
        case .night: return "#CFC9BC"
        }
    }

    var secondaryTextHex: String {
        switch self {
        case .paper: return "#706E66"
        case .sepia: return "#8C7B5C"
        case .mist:  return "#5C6B60"
        case .bold:  return "#55524C"
        case .dusk:  return "#868B93"
        case .amber: return "#A8906E"
        case .ink:   return "#9B9A8F"
        case .night: return "#8F8A80"
        }
    }

    var accentHex: String {
        switch self {
        case .paper: return "#6F7E68"
        case .sepia: return "#6E7A5F"
        case .mist:  return "#4E6B58"
        case .bold:  return "#8A2F22"
        case .dusk:  return "#A6B49E"
        case .amber: return "#D2A263"
        case .ink:   return "#A6B49E"
        case .night: return "#C39A68"
        }
    }

    /// CSS `font-weight` for body text. Bold is the one theme that reads
    /// heavier, not just darker; static faces (Charter, Georgia, Palatino)
    /// resolve 500 to regular, so there it is contrast-only. Accepted.
    var bodyFontWeight: Int { self == .bold ? 500 : 400 }
```

`shadowOpacity` switch: add `case .mist, .bold: return 0.10`, `case .amber: return 0.34`, `case .night: return 0.42`. `isDark`: `case .paper, .sepia, .mist, .bold: return false` / `case .dusk, .amber, .ink, .night: return true`. Leave `surfaceHex`, `surfaceRaisedHex`, `hairlineHex` (derived) as they are.

- [ ] **Step 4: Run the four tests + the whole `ModelTests` class**

Run: `xcodebuild test ... -only-testing:NativReadTests/ModelTests`
Expected: PASS (the PDF picker in `PDFReaderSheets.swift:273-275` only names paper/sepia/ink and keeps compiling).

- [ ] **Step 5: Commit**

```bash
git add NativRead/Models/ReaderSettings.swift NativReadTests/ModelTests.swift
git commit -m "feat(reader): four more reading atmospheres — Mist, Bold, Amber, Night"
```

---

### Task 2: Localized labels for the new themes and the panel sections

**Files:**
- Modify: `NativRead/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: keys `theme.label.mist|bold|amber|night`; `appearance.section.atmosphere|text|layout|comfort` (used by Task 6 via `Text("appearance.section.atmosphere")`-style `LocalizedStringKey`s).

- [ ] **Step 1: Add the keys with a script** (the file is JSON; keep it sorted by key like Xcode does)

```bash
python3 - <<'EOF'
import json, collections
p='NativRead/Resources/Localizable.xcstrings'
d=json.load(open(p))
def entry(comment, en, hu):
    return {"comment": comment, "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": en}},
        "hu": {"stringUnit": {"state": "translated", "value": hu}}}}
new = {
 "theme.label.mist":  entry("Display name for the Mist (sage green) reading theme.", "Mist", "Pára"),
 "theme.label.bold":  entry("Display name for the Bold (high contrast) reading theme.", "Bold", "Kontraszt"),
 "theme.label.amber": entry("Display name for the Amber (warm night) reading theme.", "Amber", "Borostyán"),
 "theme.label.night": entry("Display name for the Night (true black) reading theme.", "Night", "Éjszaka"),
 "appearance.section.atmosphere": entry("Eyebrow over the theme tiles in the appearance panel.", "Atmosphere", "Hangulat"),
 "appearance.section.text":       entry("Eyebrow over text size / typeface / spacing.", "Text", "Szöveg"),
 "appearance.section.layout":     entry("Eyebrow over margins / page flow / page turn.", "Layout", "Elrendezés"),
 "appearance.section.comfort":    entry("Eyebrow over warm light / brightness.", "Comfort", "Kényelem"),
 "appearance.typeface": entry("Row label for the collapsible typeface list.", "Typeface", "Betűtípus"),
}
d['strings'].update(new)
d['strings']=dict(sorted(d['strings'].items()))
json.dump(d, open(p,'w'), ensure_ascii=False, indent=2)
open(p,'a').write('\n')
EOF
```

- [ ] **Step 2: Verify the file still parses and the app builds**

Run: `python3 -c "import json;json.load(open('NativRead/Resources/Localizable.xcstrings'))" && xcodebuild build -project NativRead.xcodeproj -scheme NativRead -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error|BUILD"`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add NativRead/Resources/Localizable.xcstrings
git commit -m "feat(l10n): labels for the new atmospheres and appearance sections"
```

---

### Task 3: Typography foundations in the page CSS

**Files:**
- Modify: `NativRead/Services/ReaderStyle.swift:212-240` (the shared tail of `css(...)`)
- Test: `NativReadTests/ModelTests.swift`

**Interfaces:**
- Consumes: `ReaderTheme.bodyFontWeight` (Task 1).

- [ ] **Step 1: Write the failing tests**

```swift
    func testReaderStyleEmitsBodyWeightOnlyForBold() {
        var settings = ReaderSettings()
        settings.theme = .bold
        let bold = ReaderStyle.css(settings: settings, pageWidth: 390, pageHeight: 844)
        XCTAssertTrue(bold.contains("font-weight: 500"))
        settings.theme = .paper
        let paper = ReaderStyle.css(settings: settings, pageWidth: 390, pageHeight: 844)
        XCTAssertTrue(paper.contains("font-weight: 400"))
        XCTAssertFalse(paper.contains("font-weight: 500"))
    }

    func testReaderStyleEmitsSizeAwareTrackingAndOpticalSizing() {
        let css = ReaderStyle.css(
            settings: ReaderSettings(), pageWidth: 390, pageHeight: 844
        )
        XCTAssertTrue(css.contains("font-optical-sizing: auto"))
        XCTAssertTrue(css.contains("h1, h2, h3 {"))
        XCTAssertTrue(css.contains("letter-spacing: -0.01em"))
        XCTAssertTrue(css.contains("letter-spacing: 0.04em"))
    }
```

- [ ] **Step 2: Run to verify they fail**

Run: `xcodebuild test ... -only-testing:NativReadTests/ModelTests/testReaderStyleEmitsBodyWeightOnlyForBold -only-testing:NativReadTests/ModelTests/testReaderStyleEmitsSizeAwareTrackingAndOpticalSizing`
Expected: FAIL on `font-optical-sizing` / `font-weight: 500` assertions.

- [ ] **Step 3: Implement** — in the shared tail of `css(...)`, change the `body {` block and the heading block:

```swift
        return """
        \(fontFaceRule)
        :root { color-scheme: \(theme.isDark ? "dark" : "light"); }
        html { font-optical-sizing: auto; }
        \(layout)
        body {
            background: \(theme.backgroundHex) !important;
            color: \(theme.textHex) !important;
            font-family: \(settings.font.cssFamily) !important;
            font-size: \(settings.fontSize)px !important;
            font-weight: \(theme.bodyFontWeight);
            line-height: \(settings.lineHeight) !important;
            letter-spacing: 0;
            text-rendering: optimizeLegibility;
        }
```

and replace the existing `h1, h2, h3, h4, h5, h6 { line-height: 1.25 !important; ... }` rule with:

```swift
        /* Tracking and leading follow size: large heads tighten, small
           labels open up, body stays at 0 (Apple type guidance). */
        h1, h2, h3 {
            letter-spacing: -0.01em;
            line-height: 1.2 !important;
            text-align: left;
            break-after: avoid;
        }
        h4, h5, h6 {
            letter-spacing: 0;
            line-height: 1.25 !important;
            text-align: left;
            break-after: avoid;
        }
        small, .small-caps, [style*="small-caps"] { letter-spacing: 0.04em; }
```

Keep `body * { ... line-height: inherit !important; ... }` as is — it does not touch `letter-spacing` or `font-weight`, so the rules above apply. Note the `theme` variable in `css(...)` is `settings.palette(systemDark:)` (a `ReaderPalette`), so add `bodyFontWeight` to `ReaderPalette` too: in `ReaderSettings.swift` `struct ReaderPalette` add `let bodyFontWeight: Int`, and pass `bodyFontWeight: theme.bodyFontWeight` in both `palette(...)` initialisers (lines ~307-341).

- [ ] **Step 4: Run the whole unit target**

Run: `xcodebuild test ... -only-testing:NativReadTests`
Expected: 291 + 6 new pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add NativRead/Services/ReaderStyle.swift NativRead/Models/ReaderSettings.swift NativReadTests/ModelTests.swift
git commit -m "feat(reader): size-aware tracking, optical sizing and a heavier Bold body"
```

---

### Task 4: Dynamic Type as the first-launch text size

**Files:**
- Modify: `NativRead/Models/ReaderSettings.swift` (add static helper next to `fontSizeRange`)
- Modify: `NativRead/Services/SettingsStore.swift:60-66`
- Test: `NativReadTests/ModelTests.swift`

**Interfaces:**
- Produces: `static func ReaderSettings.defaultFontSize(for category: UIContentSizeCategory) -> Double`.

- [ ] **Step 1: Write the failing test**

```swift
    func testDefaultFontSizeFollowsContentSizeCategory() {
        XCTAssertEqual(ReaderSettings.defaultFontSize(for: .large), 18)
        XCTAssertEqual(ReaderSettings.defaultFontSize(for: .extraLarge), 19)
        XCTAssertEqual(ReaderSettings.defaultFontSize(for: .extraExtraLarge), 20)
        XCTAssertEqual(ReaderSettings.defaultFontSize(for: .extraExtraExtraLarge), 22)
        XCTAssertEqual(ReaderSettings.defaultFontSize(for: .accessibilityMedium), 24)
        XCTAssertEqual(ReaderSettings.defaultFontSize(for: .accessibilityExtraExtraExtraLarge), 24)
        XCTAssertEqual(ReaderSettings.defaultFontSize(for: .small), 16)
        XCTAssertEqual(ReaderSettings.defaultFontSize(for: .extraSmall), 15)
        XCTAssertEqual(ReaderSettings.defaultFontSize(for: .medium), 17)
    }

    func testSettingsStoreSeedsFontSizeFromDynamicTypeOnlyWhenNothingStored() {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let fresh = SettingsStore(defaults: defaults, contentSizeCategory: .extraExtraLarge)
        XCTAssertEqual(fresh.settings.fontSize, 20)

        fresh.update { var s = $0; s.fontSize = 13; return s }
        let reloaded = SettingsStore(defaults: defaults, contentSizeCategory: .accessibilityLarge)
        XCTAssertEqual(reloaded.settings.fontSize, 13, "a saved size always wins")
    }
```

- [ ] **Step 2: Run to verify they fail**

Expected: compile errors (`defaultFontSize`, `contentSizeCategory:` label).

- [ ] **Step 3: Implement**

In `ReaderSettings` (near `static let fontSizeRange`):

```swift
    /// First-launch text size, taken from the system Dynamic Type setting
    /// so a reader who already asked iOS for bigger text opens the book at
    /// bigger text. Only used when nothing is stored; a saved size wins.
    static func defaultFontSize(for category: UIContentSizeCategory) -> Double {
        switch category {
        case .extraSmall: return 15
        case .small: return 16
        case .medium: return 17
        case .large, .unspecified: return 18
        case .extraLarge: return 19
        case .extraExtraLarge: return 20
        case .extraExtraExtraLarge: return 22
        default: return 24   // every accessibility size
        }
    }
```

In `SettingsStore.init`, add a parameter with a default and use it:

```swift
    init(
        defaults: UserDefaults = .standard,
        defaultTranslationBackendURLString: String? = nil,
        contentSizeCategory: UIContentSizeCategory =
            UIApplication.shared.preferredContentSizeCategory
    ) {
        ...
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(ReaderSettings.self, from: data) {
            settings = decoded
        } else {
            var seeded = ReaderSettings()
            seeded.fontSize = ReaderSettings.defaultFontSize(for: contentSizeCategory)
            settings = seeded
        }
```

(`SettingsStore` is `@MainActor`; `UIApplication.shared` is fine there. Add `import UIKit` if only SwiftUI is imported.)

- [ ] **Step 4: Run the unit target**

Run: `xcodebuild test ... -only-testing:NativReadTests`
Expected: all pass. If `-resetSettings` UI runs start at a different size on the simulator, that is intended (simulator default category is `.large` → 18, unchanged).

- [ ] **Step 5: Commit**

```bash
git add NativRead/Models/ReaderSettings.swift NativRead/Services/SettingsStore.swift NativReadTests/ModelTests.swift
git commit -m "feat(reader): seed the first text size from Dynamic Type"
```

---

### Task 5: `ThemeTile` previews the chosen typeface; tabs removed

**Files:**
- Modify: `NativRead/Views/Reader/ReaderAppearanceControls.swift:223-330`
- Modify: `NativRead/Models/ReaderSettings.swift:156-166` (`ReaderFont.previewFont` gains a size parameter)

**Interfaces:**
- Produces: `ThemeTile(theme:isSelected:font:palette:action:)` — new `font: ReaderFont` parameter; `ReaderFont.previewFont(size: CGFloat = 17) -> Font`.
- Deletes: `AppearanceTab`, `SegmentedTabs`.

- [ ] **Step 1: Make `previewFont` size-parametric**

```swift
    /// SwiftUI preview font for the appearance panel. Bundled fonts use
    /// the family name iOS exposes once registered via `UIAppFonts`.
    func previewFont(size: CGFloat = 17) -> Font {
        switch self {
        case .newYork: return .system(size: size, design: .serif)
        case .sanFrancisco: return .system(size: size)
        case .georgia: return .custom("Georgia", size: size)
        case .palatino: return .custom("Palatino", size: size)
        case .charter: return .custom("Charter", size: size)
        case .crimson: return .custom("Crimson Pro", size: size)
        case .cormorant: return .custom(Typography.displayFamily, size: size)
        }
    }
```

Update the one caller in `TypographyPanel.fontList` from `.font(candidate.previewFont)` to `.font(candidate.previewFont())`.

- [ ] **Step 2: Rewrite `ThemeTile`**

```swift
/// One reading atmosphere as a little page: the "Aa" is set in the font the
/// reader currently uses, on the theme's paper, so a tile shows exactly what
/// the page will look like. Selection rings it in the theme's accent and
/// lifts it on a spring.
struct ThemeTile: View {
    let theme: ReaderTheme
    let isSelected: Bool
    let font: ReaderFont
    let palette: ReaderPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                        .fill(theme.background)
                    RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                        .strokeBorder(
                            isSelected ? theme.accent : palette.hairline,
                            lineWidth: isSelected ? 2.5 : 1
                        )
                    Text("Aa")
                        .font(font.previewFont(size: 24))
                        .fontWeight(theme == .bold ? .medium : .regular)
                        .foregroundStyle(theme.text)
                }
                .frame(height: 64)
                .scaleEffect(isSelected ? 1.0 : 0.96)
                .shadow(
                    color: .black.opacity(isSelected ? palette.shadowOpacity : 0),
                    radius: 5, y: 2
                )

                Text(theme.label)
                    .font(Typography.meta(11))
                    .foregroundStyle(isSelected ? palette.accent : palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.28), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected) { _, new in new }
        .accessibilityLabel(theme.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("theme.\(theme.rawValue)")
    }
}
```

- [ ] **Step 3: Delete `AppearanceTab` and `SegmentedTabs`** (the whole `// MARK: - Segmented tabs` section, `ReaderAppearanceControls.swift:260-330`). Leave the numeric helpers below it.

- [ ] **Step 4: Build** — expected errors only in `TypographyPanel.swift` (`SegmentedTabs`, `AppearanceTab`, `ThemeTile` call). Task 6 fixes those; do not commit yet.

---

### Task 6: `TypographyPanel` as one scrolling panel

**Files:**
- Modify: `NativRead/Views/Reader/TypographyPanel.swift` (whole `body` and the theme/typeface section; every other private view stays)

**Interfaces:**
- Consumes: `ThemeTile(theme:isSelected:font:palette:action:)` (Task 5), localization keys (Task 2).

- [ ] **Step 1: Replace state, `body`, and `tabContent`/`themeTab`/`textTab`/`layoutTab`** with:

```swift
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var brightness = UIScreen.main.brightness
    /// The typeface list is long; it folds under its row until asked for.
    @State private var isTypefaceListExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            grabber
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    section("appearance.section.atmosphere") {
                        themeGrid
                        autoThemeToggle
                    }
                    divider
                    section("appearance.section.text") {
                        sizeGroup
                        typefaceRow
                        lineSpacingGroup
                        justifiedToggle
                    }
                    divider
                    section("appearance.section.layout") {
                        marginsGroup
                        flowGroup
                        if settings.pageFlow == .paged {
                            transitionRow
                            if reduceMotion { reduceMotionRow }
                            if horizontalSizeClass == .regular { spreadToggle }
                        }
                    }
                    divider
                    section("appearance.section.comfort") {
                        warmthGroup
                        brightnessGroup
                    }
                }
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.lg)
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: settings.pageFlow)
                .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: isTypefaceListExpanded)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.height(450), .large])
        // ponytail: no presentationBackgroundInteraction — enabling it up
        // through the small detent makes iOS treat the sheet as a non-modal
        // accessory and kills swipe/flick-to-dismiss. Plain modal sheet =
        // standard flick-down dismissal.
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.hidden)
    }

    /// An eyebrow-labelled group: the panel's only structural device, so
    /// the reader can skim to a section without a mode switch.
    private func section<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            content()
        }
    }

    // MARK: - Theme tiles

    private var themeGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 4),
            spacing: Spacing.sm
        ) {
            ForEach(ReaderTheme.allCases) { candidate in
                ThemeTile(
                    theme: candidate,
                    isSelected: candidate == activeTheme,
                    font: settings.font,
                    palette: palette
                ) {
                    selectTheme(candidate)
                }
            }
        }
    }

    // MARK: - Typeface (collapsible)

    private var typefaceRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isTypefaceListExpanded.toggle()
            } label: {
                HStack {
                    ControlLabel(title: "appearance.typeface", icon: "textformat", palette: palette)
                    Spacer()
                    Text(settings.font.label)
                        .font(settings.font.previewFont(size: 15))
                        .foregroundStyle(palette.text)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .rotationEffect(.degrees(isTypefaceListExpanded ? 180 : 0))
                }
                .frame(minHeight: Spacing.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("appearance.typeface")
            .accessibilityValue(settings.font.label)

            if isTypefaceListExpanded {
                fontList
                    .padding(.leading, Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
```

Delete `tab`, `initialTab`, `tabContent`, `themeTab`, `textTab`, `layoutTab`, `themeRow`. Keep `selectTheme`, `sizeGroup`, `adjustFontSize`, `brightnessGroup`, `warmthGroup`, `lineSpacingGroup`, `marginsGroup`, the toggles, `flowGroup`/`flowRow`, `transitionRow`, `fontList` (callers updated to `previewFont()`), `grabber`, `divider`, `sliderGroup`, `updateSettings`. Update the doc comment at the top of the file:

```swift
/// The "Aa" appearance sheet: one scrolling panel in four eyebrow-labelled
/// sections — Atmosphere, Text, Layout, Comfort — with no tabs. The theme
/// tiles set "Aa" in the reader's own typeface; every control repaints the
/// page underneath as it changes.
```

`ControlLabel.title` is a `LocalizedStringKey`, so `"appearance.typeface"` resolves through the xcstrings key added in Task 2.

- [ ] **Step 2: Build and run the unit target**

Run: `xcodebuild test ... -only-testing:NativReadTests`
Expected: BUILD SUCCEEDED, all green (the UI-test target still compiles: it only references identifiers).

- [ ] **Step 3: Look at it once** — run `-only-testing:NativReadUITests/ReaderJourneyUITests/testTypographyPanelSwitchesTheme` (it will fail at the `appearance.tab.text` tap — expected) and take one `xcrun simctl io booted screenshot` while the sheet is up. Check: 8 tiles in two rows, labels legible, selected tile ringed, Text-size stepper visible without scrolling at the 450 detent. Adjust `.frame(height: 64)` → 60 only if the stepper is cut off.

- [ ] **Step 4: Commit Tasks 5+6 together**

```bash
git add NativRead/Views/Reader/ReaderAppearanceControls.swift NativRead/Views/Reader/TypographyPanel.swift NativRead/Models/ReaderSettings.swift
git commit -m "feat(reader): one scrolling appearance panel with typeface-true theme tiles"
```

---

### Task 7: UI tests follow the tabless panel

**Files:**
- Modify: `NativReadUITests/ReaderJourneyUITests.swift:200-222, 328-338, 386-420`
- Modify: `NativReadUITests/AppShowcaseScreenshotUITests.swift:128-138`

- [ ] **Step 1: `testTypographyPanelSwitchesTheme`** — remove the `appearance.tab.text` tap; the stepper is on the same panel. Also assert the new tiles exist and that Night recolours:

```swift
    func testTypographyPanelSwitchesTheme() {
        openSampleBook()
        tapMenuItem("reader.typography")

        // All eight atmospheres sit in the panel's first section.
        for theme in ["paper", "sepia", "mist", "bold", "dusk", "amber", "ink", "night"] {
            XCTAssertTrue(app.buttons["theme.\(theme)"].waitForExistence(timeout: 6), theme)
        }
        let duskSwatch = app.buttons["theme.dusk"]
        duskSwatch.tap()
        XCTAssertTrue(duskSwatch.isSelected)

        // Size lives on the same panel now — no tab to switch.
        let sizeUp = app.buttons["fontsize.up"]
        XCTAssertTrue(sizeUp.waitForExistence(timeout: 6))
        sizeUp.tap()

        // Dismiss the sheet, reopen, and confirm the choice stuck.
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["reader.menu"].waitForExistence(timeout: 6))
        tapMenuItem("reader.typography")
        XCTAssertTrue(duskSwatch.waitForExistence(timeout: 6))
        XCTAssertTrue(duskSwatch.isSelected)
    }
```

- [ ] **Step 2: Delete `testProbeChromeTour`** (the throwaway tour from the design session).

- [ ] **Step 3: `openLayoutTab` → `openLayoutSection`**

```swift
    /// Opens the appearance sheet and scrolls to the Layout section, where
    /// the page-flow and transition controls live.
    private func openLayoutSection() {
        tapMenuItem("reader.typography")
        let flow = app.buttons["flow.paged"]
        XCTAssertTrue(flow.waitForExistence(timeout: 6))
        // The sheet opens at its compact detent; pull it up so the Layout
        // section is on screen and hittable.
        app.swipeUp(velocity: .fast)
        if !flow.isHittable { app.swipeUp() }
        XCTAssertTrue(flow.isHittable, "layout section should be reachable")
    }
```

Rename both call sites in `testFlowAndTransitionPickersPersist` (`openLayoutTab()` → `openLayoutSection()`).

- [ ] **Step 4: `AppShowcaseScreenshotUITests.swift:128-138`** — replace the three tab captures with one panel capture plus a scrolled capture:

```swift
        tapReaderMenuItem("reader.typography")
        XCTAssertTrue(
            app.buttons["theme.paper"].waitForExistence(timeout: 8)
        )
        capture(locale, 10, "epub-appearance")

        app.swipeUp(velocity: .fast)
        capture(locale, 11, "epub-appearance-layout")
        dismissReaderSheet()
```

Then renumber the following captures (13 → 12, etc.) so the sequence stays contiguous; check the file for a hard-coded expected count.

- [ ] **Step 5: Run the appearance-related UI tests**

Run: `xcodebuild test ... -only-testing:NativReadUITests/ReaderJourneyUITests/testTypographyPanelSwitchesTheme -only-testing:NativReadUITests/ReaderJourneyUITests/testFlowAndTransitionPickersPersist -only-testing:NativReadUITests/SheetChromeUITests`
Expected: PASS. If `isSelected` is false on the tile, confirm `.accessibilityAddTraits(.isSelected)` from Task 5 is on the `Button`, not the inner `ZStack`.

- [ ] **Step 6: Commit**

```bash
git add NativReadUITests/ReaderJourneyUITests.swift NativReadUITests/AppShowcaseScreenshotUITests.swift
git commit -m "test(ui): appearance panel without tabs, eight atmospheres"
```

---

### Task 8: Full verification and docs touch

**Files:**
- Modify: `docs/design/editorial-redesign.md` (the "4 reading atmospheres" sentence → 8, list them)
- Modify: `CHANGELOG.md` (Unreleased: themes, panel, typography)

- [ ] **Step 1: Run everything**

Run: `xcodebuild test -project NativRead.xcodeproj -scheme NativRead -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: unit 0 failures; UI 0 failures (the showcase screenshot test may be skipped by its own locale guard — that is fine).

- [ ] **Step 2: Acceptance by eye** — `-forceTheme night -showTypographyPanel` launch: the page is true black, tiles show Night ringed; `-forceTheme bold` with Crimson Pro selected reads visibly heavier than Paper. One screenshot each via `xcrun simctl io booted screenshot`.

- [ ] **Step 3: Docs**

In `docs/design/editorial-redesign.md` replace
`The 4 reading atmospheres (Paper/Sepia/Dusk/Ink) keep their intentional per-atmosphere accents.`
with
`The 8 reading atmospheres (Paper/Sepia/Mist/Bold · Dusk/Amber/Ink/Night) keep their intentional per-atmosphere accents; Bold also sets body weight 500. The appearance sheet is one scrolling panel (Atmosphere · Text · Layout · Comfort), no tabs — see docs/superpowers/specs/2026-09-14-reading-atmospheres-and-appearance-panel-design.md.`

`CHANGELOG.md` under Unreleased:
```
- Reader: four new atmospheres — Mist (sage), Bold (high contrast, heavier body), Amber (warm night), Night (true black).
- Reader: the Aa panel is one scrolling sheet; theme tiles preview your typeface; typeface list folds under its row.
- Reader: size-aware tracking/leading and optical sizing on the page; first text size follows Dynamic Type.
```

- [ ] **Step 4: Commit and push**

```bash
git add docs/design/editorial-redesign.md CHANGELOG.md
git commit -m "docs: eight atmospheres and the tabless appearance panel"
git push origin feat/welcome-tips-translate-redesign
```
