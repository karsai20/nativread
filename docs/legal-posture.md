# Legal & data posture — NativRead translator

Status: REVIEWED 2026-06-29 — **PASS WITH CONDITIONS** (legal-reviewer agent).
EU AI Act section added 2026-07-06 (/ship compliance pass).
**Not formal legal advice — get a qualified attorney's sign-off before
commercial launch.**

> **Verdict (2026-06-29, corrected 2026-08-05):** The architecture is
> App-Store-compatible, and the *user-facing* posture is defensible as
> designed. The product does NOT need a redesign to reach App Review.
> Survivability there hinges on executing the MUST-FIX items below —
> especially the ones a reviewer actually sees (#1 ownership attestation,
> #2 metadata scrub, #4 privacy disclosure, #5 account deletion) — plus the
> DeepSeek terms answer (#3).
>
> The residual legal exposure that survives even a perfect implementation is
> the **operator's own act of adaptation**: the server, not the user, creates
> the derivative work, for money. The original wording called this a
> "fair-use-flavored risk-tolerance stance" — that framing is a US import and
> is **wrong for an EU/HU operator**. There is no fair use here, only the
> closed exception list of InfoSoc Art 5 plus national adaptation law; no
> listed exception covers a commercial provider performing the adaptation.
> Attestation, ephemerality, and per-user isolation lower enforcement
> probability and provable damages; they do not create a legal basis.
> **Chosen posture (2026-08-04): accept that exposure and shift responsibility
> to the user by contract.** That choice is only as strong as its carriers —
> a limited-liability entity and the counsel read (still open, TODOS P1).

## The model this covers

Public iOS app (App Store) + operator-run backend + **per-book purchase via Apple
IAP** (free first chapter) + a **Western, training-excluded AI provider** (NOT
DeepSeek's direct API — see principle 4 / MUST-FIX #3). Apple + Google login;
ephemeral server with the durable copy in the user's own cloud.

This is the deliberate **opposite** of `nativread-translator`'s posture. That
project's entire legal cleanliness rested on *"private household LAN, not a
public service"* (see `nativread-translator/PLAN.md` → "Legal / data posture"). A
public, operator-run, paid app **inverts every one of those assumptions**, so
none of that protection carries over. The constraints below replace it.

## Core principles (these keep it defensible)

1. **User supplies their own books.** No built-in acquisition, catalog, search,
   or sideload of books. The app translates an EPUB the user already has. No
   feature that helps obtain copyrighted books → avoids App Store Guideline 5.2
   (intellectual property) rejection and facilitation claims.

0. **Two things missing from the original analysis (added 2026-08-05).**
   - **The three-step test (InfoSoc Art 5(5), Berne 9(2)).** Even where a
     national reading of private adaptation is favourable, the use must not
     conflict with the normal exploitation of the work. That conflict is
     **title-dependent**: where a licensed Hungarian edition exists, the
     output substitutes it directly and the test bites hardest; where none
     exists (long tail, out of print, never translated), the argument largely
     falls away. Consequence: do not position or market the product on
     bestsellers that already have a licensed translation in the target
     language, and give counsel this segmentation rather than a single
     yes/no question.
   - **No hosting safe harbour (DSA Art 6).** The service does not merely
     store files at a user's request — it creates the translation. The
     rightsholder-notice route is therefore a voluntary good-faith process,
     not statutory immunity, and must not be described as if it were. Terms
     clause 7.7 now says so explicitly.

2. **Translation is a derivative work — keep it private and per-user.**
   - Personal translation of a user's own legally-owned book, for their own
     reading, is the defensible case (akin to a private translation for personal
     use).
   - **No shared/global translated library.** `nativread-translator`'s "household
     library, never re-translate" must NOT become a cross-user cache. The moment
     one user's translation is served to another, the operator is **storing and
     distributing derivative copies of copyrighted works** — clear infringement.
   - Store each user's translations **scoped to their own account only**.
     Per-user dedup (don't re-translate the *same user's* re-upload) is fine;
     cross-user dedup is not.

3. **The operator is a neutral conduit; the user owns the upload.** The EULA/ToS
   must state the user warrants they have the right to translate what they
   upload, and that responsibility for the content is theirs. Operator does not
   review, curate, or redistribute uploads.

4. **Disclose the third-party AI processor.** Translation sends book text to a
   third-party AI API. **Provider decision (2026-06-30): NOT DeepSeek's direct
   API** — its published terms store data in China and use inputs for training by
   default with no clean API carve-out (Privacy Policy eff. 2026-02-10, verified
   live). Use a **Western, training-excluded API** (default Gemini Flash-class;
   OpenAI-mini / Claude Haiku alternates) with EU/US region + a DPA. The same
   DeepSeek *model* (open weights) on a Western ZDR host was the alternative; the
   chosen path is a Western API for clean terms + low cost. Regardless of which:
   - state in-app before the first translation ("translated with AI"),
   - declare the named provider in App Store privacy labels + privacy policy,
   - sign the provider's DPA.

5. **GDPR (EU users).** Book content + account/PII are personal data when tied to
   an account. Needs: lawful basis, privacy policy, processor disclosure
   (AI provider + host), data-subject rights (export/delete), retention limits.
   **The China-transfer (Chapter V) problem is RESOLVED by choosing a Western
   provider with EU/US region** — what remains is standard GDPR hygiene, not the
   hard transfer-impact-assessment for China.

## IAP-specific obligations (this model)

A book translation is **digital content consumed in the app**, so:

- **Must use Apple In-App Purchase** (StoreKit). You may **not** use an external
  payment processor (Stripe etc.) for it — Guideline 3.1.1. Apple takes 15–30%.
- The purchase is a **consumable** SKU (a length-tiered "translate this book"
  product); a verified StoreKit 2 transaction grants an **entitlement per
  `(userId, sourceHash)`** server-side. No abstract credit ledger.
- Verify StoreKit transactions server-side before granting the entitlement —
  never trust the client. **Dedupe on transaction id** so a retry never
  double-grants.
- The **free first chapter** is a try-before-buy, not a purchase: always the
  real first chapter, once per `(userId, sourceHash)`, rate-limited + word-capped
  to bound abuse. It is not an IAP product and needs no receipt.
- No "buy cheaper on our website" steering inside the app (anti-steering rules;
  narrow carve-outs exist but assume not).
- Show price tier and exactly what the purchase translates before buying.

## Login (why it exists here)

**Sign in with Apple + Google.** Login is renativreadd not for the feature but to:
- attribute and verify per-book entitlements to a user (anti-fraud),
- enforce per-user quota / cost ceiling (anti-abuse of the shared DeepSeek key),
- scope stored content privately to one account (principle 2),
- route the durable copy to the user's own cloud (iCloud for Apple, Google Drive
  for Google) — the book lives in the USER's cloud, not the operator's.

Offering Google is allowed because **Sign in with Apple is also offered** —
Apple's third-party-login rule (4.8 / 5.1.1) is satisfied. Apple and Google
logins are separate accounts in Phase 1 (Apple private-relay email makes
cross-provider linking unreliable).

## Cost & abuse controls (server-side)

- The AI provider API key lives **only** on the server, never in the app binary.
- A per-book entitlement gates the paid job; the free first chapter is bounded
  (real-first-content-chapter only, `(userId, sourceHash)` dedup, rate limit,
  word cap).
- Reuse `nativread-translator`'s `COST_CEILING_USD` per-book ceiling, a per-user/day
  rate limit, **and a global daily spend kill-switch** on the free endpoint
  (per-user caps don't bound aggregate spend). Cost derived from `cost.ts`.

## Explicitly NOT doing

- No shared/global library of translated copyrighted books.
- No book acquisition, discovery, or piracy-adjacent features.
- No external payment for the in-app purchase.
- No undisclosed data egress.
- No DeepSeek direct API (China storage + default training); Western
  training-excluded provider instead.

## EU AI Act (Regulation (EU) 2024/1689) — added 2026-07-06

**Classification.** The translator is an AI system the operator places on the EU
market (provider role). The underlying LLM is a third-party GPAI model used via
API without fine-tuning → the GPAI-model obligations (Chapter V) sit with the
model provider (Google/OpenAI/Anthropic), not with us. Literary machine
translation is not a prohibited practice (Art 5) and is not Annex III high-risk
→ **limited-risk system: only the Art 50 transparency obligations apply.**
They apply from **2 August 2026** — before our commercial launch window, so
treat them as launch gates alongside the MUST-FIX list.

**Obligations → concrete actions:**

1. **Art 50(2) — machine-readable marking of AI-generated text.** Translated
   output must be detectable as artificially generated in a machine-readable
   format. Action: embed an "AI-generated (machine translation)" marker in the
   translated EPUB's OPF metadata at delivery, and preserve it on re-export
   from the app (share sheet / Send to Kindle). A translation of a user's own
   text arguably falls near the Art 50(2) assistive-edit carve-out, but the
   marker costs one `<meta>` element — take the conservative path.
2. **Art 50(1)-adjacent visible disclosure.** The pre-translation "translated
   with AI" notice (MUST-FIX #4) plus a persistent, explicit **"AI-translated"**
   label on translated books. The current title suffix ("Hungarian preview")
   marks *translated*, not *AI* — one copy pass fixes it. Same wording ships in
   the reader surface and the book detail.
3. **Art 4 — AI literacy.** Solo operator; noted, nothing to build.
4. **Users have no deployer duties** for private reading (no Art 50(4)
   "inform the public" scenario). Nothing to surface to them beyond #2.

**Penalty context:** transparency breaches carry fines up to €15M / 3% of
turnover — disproportionate exposure for a two-line metadata fix. Comply even
in the local-backend MVP so the public launch inherits it.

## Open-source & content licensing — added 2026-07-06

- **Bundled GPL dictionaries: RESOLVED by removal** (2026-07-06 branch). The
  FreeDict/StarDict bundles are gone; word lookup stays in Apple's native Look
  Up surface. No GPL code or data ships in the binary.
- **ZIPFoundation (MIT)** — the only external package. MIT renativreads the license
  text to accompany the distribution: add an in-app acknowledgements/licenses
  entry (Settings → About). Cheap, standard, do before App Store submission.
- **Test fixtures** (Standard Ebooks Alice/Tenniel AZW3) are public-domain and
  test-target-only; they do not ship to users. No action.

## MUST-FIX before launch (hard gates — from legal review)

These are launch blockers. The starred ones (★) are what App reviewers actually
see and are the make-or-break for getting on the store.

1. ★ **In-flow ownership attestation, in the binary.** An affirmative "I own
   this book and have the right to translate it for personal use" gate before
   the first upload/translation — NOT buried in the ToS. Primary 5.2 survival
   artifact; reviewers must see it.
   **Regressed and restored:** Terms v1.1 (2026-08-03) folded the statement
   into clause 7.1 and left the screen reading only "I accept the Terms of
   Use", while the acceptance record kept asserting a rights statement
   (`statementVersion`). v1.2 (2026-08-05) puts the sentence back on the
   checkbox. Any future shortening of that copy re-opens this gate — the
   wording is pinned in `docs/legal/in-app-legal-copy.md` §1.
2. ★ **Scrub all App Store metadata + in-app copy** of any wording implying
   users can obtain, find, or read books they don't own. Position strictly as
   "translate books you already own." Marketing copy is reviewed under 5.2.
3. **RESOLVED — use a Western training-excluded provider, not DeepSeek's API.**
   DeepSeek's live terms (verified 2026-06-30) store data in China and train on
   inputs by default with no clean API carve-out. Decision: Western API
   (Gemini-Flash-class default; OpenAI-mini / Claude Haiku alternates), EU/US
   region, signed DPA, API data excluded from training. This neutralizes the
   training/retention and copyright aggravators. Remaining task: pick the model
   that clears the quality bar at acceptable cost (plan T15).
4. ★ **Accurate App Store privacy nutrition labels + in-app pre-translation
   disclosure** naming the chosen AI provider's third-party transfer. Undisclosed
   egress is an independent rejection vector (5.1.1/5.1.2).
5. ★ **In-app account + data deletion** (Apple 5.1.1(v) renativreads it
   independently of GDPR) plus data export.
6. **Per-user isolation enforced by construction, not convention.** Cross-user
   dedup/serving must be impossible — keyed strictly to account ID. This is the
   single line that, if crossed, converts the design from defensible to clear
   infringement.
7. **Live privacy policy + ToS at submission** with the user warranty/indemnity
   and named sub-processors (the AI provider + host **+ the backend error-monitoring
   provider — Sentry-class, added by CEO decision D6**). Apple checks the URL.
   Error monitoring is backend-only with book content scrubbed from payloads, and
   the iOS app ships with no analytics/monitoring SDK so its privacy nutrition
   labels stay clean. The conversion funnel (CEO D5) is first-party (own Postgres),
   so it adds **no** sub-processor.
8. **Server-side StoreKit 2 transaction verification before granting the
   entitlement** (never client-trusted); dedupe on transaction id; show the
   length tier + price + exactly what is translated before purchase.
9. **EU AI Act Art 50 transparency (applies 2026-08-02):** machine-readable
   AI-generated marker in every delivered/exported translated EPUB + explicit
   "AI-translated" user-facing label. See the EU AI Act section above; tracked
   as plan task T25 and in `TODOS.md` → Legal & compliance.

## SHOULD-FIX

- ~~GDPR Chapter V China-transfer mechanism~~ **RESOLVED** by choosing a Western
  provider with EU/US region — no China transfer, so no Chapter V TIA needed.
  Standard GDPR hygiene (DPA, privacy policy, data-subject rights) remains.
- ~~Default-short retention~~ **ADOPTED as the chosen posture (no longer just a
  should-fix):** ephemeral processing + deliver-then-delete. Source EPUB deleted
  on job completion; translated EPUB auto-deleted on a 14-day post-delivery
  window (30-day hard cap if undelivered); long-term server state is metadata
  only (userId, sourceHash, entitlement, transaction id), never book content.
  The durable copy of the translation lives in the **user's own cloud**
  (iCloud/CloudKit now, Google Drive Phase 2), not the operator — the cleanest
  cloud-locker posture (user-directed, user-owned storage). Reinstall restores
  from the user's cloud, not our server. See `translator-plan.md` backend §5.
- Abuse/takedown path: disable an account on a credible rightsholder complaint —
  cheap, strengthens the good-faith-conduit posture.
- Keep the per-user cost ceiling + per-day rate limit (from nativread-translator)
  genuinely enforced server-side; doubles as abuse control on the shared key.
- Counsel to pressure-test the personal-use derivative position specifically
  under the operator-stores-the-copy fact pattern.
