# NativRead — Editorial / Literary-Modern Redesign

Direction adopted 2026-06 after market research (2025–26 reading apps trend
typography-first and content-led; Kobo/Readwise clean redesigns; Apple Books as
the "clean reading UI" benchmark). NativRead moves off the dark-academia brand toward
a warm, editorial identity where **the book is the hero**.

## Design tokens (`NativRead/DesignSystem/`)

- **`BrandPalette`** — the app-chrome identity, separate from the per-book
  `ReaderPalette`. Light: paper `#F7F3EC`, ink `#1A1714`, russet accent `#9A3B2E`.
  Dark: `#1C1916` / `#E9E2D6` / coral `#C25A45`. Surfaces derived with the same
  `blendHex` amounts as `ReaderTheme`.
- **`Typography`** — `display` (Cormorant Garamond), `title`/`body` (Crimson Pro),
  `eyebrow` (tracked uppercase SF labels), `meta` (SF captions).
- **`Spacing`** — spacing scale, radii, tap target, hairline.
- **`PaletteColors`** — shared protocol so `ReaderPalette` and `BrandPalette`
  drive the same chrome components without conversion.

## What uses what

- **Library and onboarding** → `BrandPalette` (its own constant identity,
  following system light/dark). The shelf no longer morphs with the reading
  theme. Reading statistics and saved vocabulary were removed in the 2026-07-20
  product simplification.
- **Reader page + reader chrome + reading-context sheets** (Typography panel,
  Contents, Search) → keep `ReaderPalette` for COLOR (they melt into the open
  page), but adopt the shared `Typography`/`Spacing` for an editorial feel.
  Selected text uses Apple's native Look Up action rather than an app-owned
  definition sheet.
- The 4 reading atmospheres (Paper/Sepia/Dusk/Ink) keep their intentional
  per-atmosphere accents. The default theme is **Paper**, which matches the
  brand. Default reading font is **Charter**.

## Open follow-up: app icon

The current app icon is still the finalized **dark-academia** mark (pine-green +
brass). It is intentionally retained for now; it sits slightly apart from the new
editorial chrome. A follow-up editorial icon variant (warm paper + russet +
Cormorant wordmark) is recommended if we want full brand coherence.
