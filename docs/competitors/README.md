# Competitor app icons

App Store icon artwork (1024×) for e-reader competitors, pulled via the
iTunes lookup API for visual comparison against NativRead's own icon
(`../../NativRead/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`).

| File | App | Background | Motif |
|---|---|---|---|
| `apple-books.png` | Apple Books | Orange gradient | Open book, glossy, no text lines |
| `kindle.png` | Amazon Kindle | Blue night sky | Child reading silhouette (no book glyph) |
| `kobo.png` | Rakuten Kobo | Solid red | Wordmark only |
| `kybook3.png` | KyBook 3 | Red gradient | Serif lowercase "k" lettermark |
| `google-play-books.png` | Google Play Books | White | Play triangle + bookmark |
| `libby.png` | Libby (OverDrive) | Maroon | Teal open book + bookmark |
| `yomu.png` | Yomu | Near-black | White outline open book w/ lines |
| `readest.png` | Readest | White | **Open book, parchment pages, text lines, ribbon** |
| `readera.png` | ReadEra | Royal blue | Orange outline open book + lines + ribbon |
| `fbreader.png` | FBReader | Sky blue | Open book, text lines, red ribbon |
| `eboox.png` | eBoox | Pink/orange gradient | White open book glyph |
| `pocketbook.png` | PocketBook | Teal-green | Row of classic book spines |
| `readwise-reader.png` | Readwise Reader | Dark navy | Serif "R" + page curl |

## Takeaways vs. NativRead

- **Open-book silhouette is the crowded default** — 8 of 13 use it
  (Apple, Yomu, Readest, ReadEra, FBReader, eBoox, Libby, + NativRead).
  The glyph alone does not differentiate.
- **Readest is the closest collision**: open book + parchment pages +
  faint text lines + a hanging ribbon — almost exactly NativRead's recipe,
  just on white instead of dark pine-green.
- **ReadEra & FBReader** also pair an open book with text lines and a
  ribbon. NativRead shares all three elements with this whole cluster.
- **Background colour is the real distinguisher.** The strongest icons
  here lean on one saturated field (Kobo red, KyBook red, Apple orange,
  ReadEra blue). NativRead's dark pine-green is distinctive in the set —
  only PocketBook (teal-green) and Libby (maroon/teal) are nearby.
- **Lettermarks read cleanest at small sizes** (KyBook "k", Readwise
  "R", Kobo wordmark). NativRead's detailed parchment/ribbon scene risks
  muddiness in the home-screen / Spotlight small renders.

Source: `https://itunes.apple.com/lookup?id=<appId>&country=us` →
`artworkUrl512` upscaled to 1024.
