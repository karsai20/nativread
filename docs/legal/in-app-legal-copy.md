# In-app legal copy (HU + EN) — attestation, disclosure, colophon, states

**DRAFT — pending legal review.** Source of truth for the exact strings the
app ships. Task mapping: T23 (attestation), T16 (AI disclosure), T25
(colophon + marker), eng D4 (refusal), eng D11 (restore guarantee). All
strings ride the editorial voice: plain, large, reassuring — no legalese on
screen; the long documents live at [[TERMS_URL]] / [[POLICY_URL]].

## 1. Ownership attestation (T23 — shown at EVERY upload, one checkbox + confirm)

HU:
> **A sajátod ez a könyv?**
> A fordítást csak a saját példányodból, kizárólag a magad számára
> készítjük el.
>
> ☐ Kijelentem, hogy ez a könyv jogszerűen az enyém, és a fordítást csak
> személyes használatra kérem.
>
> [Mégse] [Fordítás indítása]

EN:
> **Is this book yours?**
> We translate only your own copy, only for you.
>
> ☐ I confirm this book is lawfully mine and I request the translation for
> my personal use only.
>
> [Cancel] [Start translation]

## 2. AI-provider disclosure (T16 — shown once, before the first translation)

HU:
> **Mielőtt elindulna az első fordítás**
> A fordítást mesterséges intelligencia készíti ([[AI_PROVIDER]]
> szolgáltatásával). A könyved szövege csak a fordítás idejére kerül
> feldolgozásra, a modell tanítására nem használják, és a szerverünkön nem
> marad meg. Részletek: Adatkezelési tájékoztató.
>
> [Tájékoztató megnyitása] [Értem, kezdjük]

EN:
> **Before your first translation**
> Translations are made by AI (using [[AI_PROVIDER]]). Your book's text is
> processed only for the duration of the translation, is not used to train
> the model, and is not kept on our server. Details: Privacy Policy.
>
> [Open policy] [Got it, let's go]

## 3. Colophon page (T25 — appended to every translated EPUB; the human-readable Art 50 companion)

HU:
> Ezt a könyvet mesterséges intelligencia fordította a NativBook
> alkalmazással, a tulajdonos saját példányából, személyes használatra.
> AI-fordítás · NativBook · [[EFFECTIVE_DATE_YEAR]]

EN:
> This book was translated by artificial intelligence with the NativBook
> app, from the owner's own copy, for personal use.
> AI translation · NativBook · [[EFFECTIVE_DATE_YEAR]]

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
> A NativBook a saját, DRM-mentes könyveiddel működik (EPUB, PDF, TXT, AZW3).
> A másolásvédett (DRM-es) könyveket a védelem miatt nem tudjuk megnyitni
> vagy lefordítani.

EN:
> NativBook works with your own DRM-free books (EPUB, PDF, TXT, AZW3).
> Copy-protected (DRM) books can't be opened or translated because of their
> protection.

## 8. Library badge + title suffixes (shipped 2026-07-06 — recorded here for completeness)

- Badge: `AI · HU` (per language: `AI · DE`, `AI · ES`)
- Title suffixes: "(AI Hungarian preview)" / "(AI Hungarian translation)" and
  localized equivalents.
