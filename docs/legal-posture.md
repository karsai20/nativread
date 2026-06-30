# Legal & data posture — NativRead translator

Status: REVIEWED 2026-06-29 — **PASS WITH CONDITIONS** (legal-reviewer agent).
**Not formal legal advice — get a qualified attorney's sign-off before
commercial launch.**

> **Verdict (2026-06-29):** The architecture is App-Store-compatible and
> legally defensible *as designed*. The product does NOT need a redesign.
> Survivability at App Review hinges on executing the MUST-FIX items below —
> especially the ones a reviewer actually sees (#1 ownership attestation,
> #2 metadata scrub, #4 privacy disclosure, #5 account deletion) — plus the
> DeepSeek terms answer (#3). The residual legal exposure that survives even a
> perfect implementation is the personal-use-derivative position under an
> *operator-stores-the-copy* fact pattern: it is a fair-use-flavored
> risk-tolerance stance, not a guaranteed statutory defense. Acceptable for
> launch given the conduit posture; have counsel pressure-test it.

## The model this covers

Public iOS app (App Store) + operator-run backend + **per-book purchase via Apple
IAP** (free first chapter) + a **Western, training-excluded AI provider** (NOT
DeepSeek's direct API — see principle 4 / MUST-FIX #3). Apple + Google login;
ephemeral server with the durable copy in the user's own cloud.

This is the deliberate **opposite** of `quire-translator`'s posture. That
project's entire legal cleanliness rested on *"private household LAN, not a
public service"* (see `quire-translator/PLAN.md` → "Legal / data posture"). A
public, operator-run, paid app **inverts every one of those assumptions**, so
none of that protection carries over. The constraints below replace it.

## Core principles (these keep it defensible)

1. **User supplies their own books.** No built-in acquisition, catalog, search,
   or sideload of books. The app translates an EPUB the user already has. No
   feature that helps obtain copyrighted books → avoids App Store Guideline 5.2
   (intellectual property) rejection and facilitation claims.

2. **Translation is a derivative work — keep it private and per-user.**
   - Personal translation of a user's own legally-owned book, for their own
     reading, is the defensible case (akin to a private translation for personal
     use).
   - **No shared/global translated library.** `quire-translator`'s "household
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

**Sign in with Apple + Google.** Login is required not for the feature but to:
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
- Reuse `quire-translator`'s `COST_CEILING_USD` per-book ceiling, a per-user/day
  rate limit, **and a global daily spend kill-switch** on the free endpoint
  (per-user caps don't bound aggregate spend). Cost derived from `cost.ts`.

## Explicitly NOT doing

- No shared/global library of translated copyrighted books.
- No book acquisition, discovery, or piracy-adjacent features.
- No external payment for the in-app purchase.
- No undisclosed data egress.
- No DeepSeek direct API (China storage + default training); Western
  training-excluded provider instead.

## MUST-FIX before launch (hard gates — from legal review)

These are launch blockers. The starred ones (★) are what App reviewers actually
see and are the make-or-break for getting on the store.

1. ★ **In-flow ownership attestation, in the binary.** An affirmative "I own
   this book and have the right to translate it for personal use" gate before
   the first upload/translation — NOT buried in the ToS. Primary 5.2 survival
   artifact; reviewers must see it.
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
5. ★ **In-app account + data deletion** (Apple 5.1.1(v) requires it
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
- Keep the per-user cost ceiling + per-day rate limit (from quire-translator)
  genuinely enforced server-side; doubles as abuse control on the shared key.
- Counsel to pressure-test the personal-use derivative position specifically
  under the operator-stores-the-copy fact pattern.
