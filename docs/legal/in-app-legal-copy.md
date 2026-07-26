# In-app legal copy (HU + EN) — attestation, disclosure, colophon, states

**DRAFT — pending legal review.** Source of truth for the exact strings the
app ships. Task mapping: T23 (attestation), T16 (AI disclosure), T25
(colophon + marker), eng D4 (refusal), eng D11 (restore guarantee). All
strings ride the editorial voice: plain, large, reassuring — no legalese on
screen. The privacy policy is also available at
https://nativread.com/privacy/.

## 1. Terms acceptance (shown once per book and terms version, before upload)

HU:
> **Saját könyv, saját jogosultság**
>
> ☐ Kijelentem, hogy a könyvet jogszerűen szereztem be, és rendelkezem a
> fordításhoz szükséges engedéllyel vagy más jogalappal. A fordítást kizárólag
> saját, személyes, nem kereskedelmi olvasásra használom; nem teszem közzé,
> nem terjesztem, nem adom el és nem osztom meg. Elfogadom a Felhasználási
> feltételeket (2026. július 22.).
>
> [Felhasználási feltételek elolvasása]

EN:
> **Your book, your rights**
>
> ☐ I confirm that I lawfully acquired this book and have the necessary
> permission or another lawful basis to translate it. I will use the
> translation only for my own personal, non-commercial reading and will not
> publish, distribute, sell, or share it. I accept the Terms of Use
> (22 July 2026).
>
> [Read the Terms of Use]

The box is empty by default for a new book/version. Acceptance is stored
locally and server-side with the authenticated account, book fingerprint,
client/server timestamps, acceptance ID, method, locale, attestation version,
terms version, and immutable terms URL. A material update requires renewed
acceptance before the next translation. AI-provider permission remains a
separate affirmative action and is never bundled into this checkbox.

## 2. AI-provider permission (T16 — shown before third-party processing)

HU:
> **Mielőtt fordítunk**
> Az engedélyed szükséges, mielőtt ezt a könyvet AI-fordítás céljából
> továbbítjuk. A könyv szövegét a Google Gemini API, egy külső AI-szolgáltatás
> dolgozza fel. A fizetős API a szöveget nem használja modellek fejlesztésére.
> A NativRead szerverpéldányai a feldolgozás és kézbesítés után, megszakadt
> kézbesítésnél legfeljebb 30 napon belül törlődnek. A szolgáltatást csak
> 18 éven felüliek használhatják.
>
> [Adatkezelési tájékoztató elolvasása] [AI-fordítás engedélyezése] [Most nem]

EN:
> **Before we translate**
> Your permission is needed before this book is shared for AI translation.
> The book text is processed by Google Gemini API, a third-party AI service.
> Its paid API does not use the text to improve models. NativRead's server
> copies are deleted after processing and delivery, or within 30 days if
> delivery is interrupted. This service is for adults aged 18 or over.
>
> [Read the Privacy Policy] [Allow AI translation] [Not now]

Permission is versioned separately from Terms acceptance. A provider or
material processing change requires renewed permission. The backend rejects
missing, stale, or provider-mismatched permission.

## 3. Colophon page (T25 — appended to every translated EPUB; the human-readable Art 50 companion)

HU:
> Ezt a könyvet mesterséges intelligencia fordította a NativRead
> alkalmazással, a tulajdonos saját példányából, személyes használatra.
> AI-fordítás · NativRead · [[EFFECTIVE_DATE_YEAR]]

EN:
> This book was translated by artificial intelligence with the NativRead
> app, from the owner's own copy, for personal use.
> AI translation · NativRead · [[EFFECTIVE_DATE_YEAR]]

(The machine-readable OPF marker spec lives in blueprint §5 / task E1 — the
colophon is its human-readable pair and must never ship without it.)

## 4. Moderation refusal — free chapter (eng D4; distinct from transient error, NO retry button)

HU:
> **Ezt a könyvet nem tudjuk automatikusan lefordítani.**
> A fordítást végző AI tartalmi szabályai elutasították a szöveget. Ez nem a
> te hibád, és az ingyenes fejezeted nem veszett el — egy másik könyvvel
> bármikor próbálkozhatsz.

EN:
> **We can't translate this book automatically.**
> The AI provider's content rules declined this text. This isn't your fault,
> and your free chapter wasn't used — try another book anytime.

## 5. Paid-job failure → refund (T6 — never silent)

HU:
> **A fordítás elakadt — dolgozunk rajta.**
> Automatikusan újrapróbáljuk. Ha nem sikerül befejezni, a vételárat
> visszatérítjük. Nem kell tenned semmit.

EN:
> **The translation hit a snag — we're on it.**
> We retry automatically. If it can't be completed, you'll be refunded. No
> action needed.

## 6. Restore guarantee (eng D11 — purchase sheet, one quiet line under the price)

HU:
> A vásárlásod a fiókodhoz kötődik: ha újratelepíted az appot vagy készüléket
> váltasz, ugyanezt a könyvet újra feltöltve a fordításod ingyen visszakapod.

EN:
> Your purchase is tied to your account: reinstall or switch devices, upload
> the same book again, and you get your translation back free.

## 7. DRM expectation copy (onboarding, §1 DRM-reality — honest, no acquisition pointers)

HU:
> A NativRead a saját, DRM-mentes könyveiddel működik (EPUB, PDF, TXT, AZW3).
> A másolásvédett (DRM-es) könyveket a védelem miatt nem tudjuk megnyitni
> vagy lefordítani.

EN:
> NativRead works with your own DRM-free books (EPUB, PDF, TXT, AZW3).
> Copy-protected (DRM) books can't be opened or translated because of their
> protection.

## 8. Library badge + title suffixes (shipped 2026-07-06 — recorded here for completeness)

- Badge: `AI · HU` (per language: `AI · DE`, `AI · ES`)
- Title suffixes: "(AI Hungarian preview)" / "(AI Hungarian translation)" and
  localized equivalents.
