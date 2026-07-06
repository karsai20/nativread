# NativRead translator — engineering plan (server + Apple/Google login + per-book IAP)

Status: PLAN (reviewed 2026-06-30, /plan-eng-review + /plan-ceo-review). Legal
gate: see [`legal-posture.md`](./legal-posture.md) — **PASS WITH CONDITIONS**; the
MUST-FIX items there are build tasks here. EU AI Act (Art 50 transparency,
applies 2026-08-02) folded in 2026-07-06 as MUST-FIX #9 → task T25.

## CEO review decisions (2026-06-30, SELECTIVE EXPANSION)

These override the matching items below; see the CEO plan in
`~/.gstack/projects/karsai20-nativread/ceo-plans/2026-06-30-translator.md`.

- **D1 — Compressed paid MVP.** Phase 1a (free-chapter probe) and Phase 1b (paid)
  **ship together in one App Review cycle.** Founder wants revenue from day one and
  accepts building money/durability machinery before stranger-demand is proven. The
  free first chapter stays as in-MVP try-before-buy, not a separate validation deploy.
- **D3.1 — Hungarian-only at launch.** Quality is validated only for Hungarian; add
  target languages post-launch, each gated on the quality bar. (Multi-language → TODOS.)
- **D3.2 — Learner inline-gloss mode → deferred to TODOS** (strong Phase 2 bet).
- **D3.3 — Keep iCloud/CloudKit durability (T13) in the launch MVP** (P2→P1) for the
  clean "book lives in the user's own cloud" legal-locker story.
- **D4 — Pricing: value-anchored length ladder** (replaces "3 tiers"). 5-6
  pre-registered StoreKit consumables, tier chosen at upload from the `cost.ts`
  estimate: <100pp $2.99 / 100-200 $3.99 / 200-350 $4.99 / 350-550 $6.99 / 550-800
  $8.99 / 800+ $11.99 (breakpoints tuned so margin stays positive on long books).
  **Truly dynamic per-token pricing is barred by Apple IAP** (pre-registered SKUs
  only, Guideline 3.1.1) — the ladder is the compliant approximation. Pricing/margin
  risk is now RESOLVED.
- **D5 — Funnel instrumentation in launch scope** (new task T18): free-chapter-completed
  → purchase-started → purchase-completed, segmented by length tier + language. It is
  the only way to read the demand signal once 1a is folded into the paid launch.
- **D6 — Monitoring posture (new task T19):** **first-party funnel events in the
  existing Postgres** (no new sub-processor, no privacy-label entry) **+ backend-only
  Sentry-class error monitoring** (payloads scrubbed of book content, disclosed as a
  sub-processor per legal #7) to page on paid-but-undelivered. iOS app stays SDK-free.

## Decision recap

- **Model:** public iOS app + operator-run backend + **per-book purchase** (Apple
  IAP) with a **free first chapter** (try-before-buy) — NOT abstract credits.
  UI says "AI-translated"; the chosen provider is named only in the legal/privacy
  layer.
- **Provider: a Western, training-excluded API (cost-optimized), NOT DeepSeek's
  direct API.** DeepSeek's published terms store data in China and use inputs for
  training by default with no clean API carve-out (verified 2026-06-30 — Privacy
  Policy eff. 2026-02-10). A Western API (default: **Gemini Flash-class** for
  cost; OpenAI-mini / Claude Haiku as alternates) excludes API data from training
  by default, offers EU/US region + a DPA. **This dissolves the two hardest legal
  items: China data-transfer (GDPR Chapter V) and training/retention (MUST-FIX
  #3).** The `Translator` interface makes it a provider swap; re-validate Hungarian
  literary quality with the existing quality pipeline. Cost levers: cheap base
  model + stronger model only on weak chunks (existing threshold routing) + prompt
  caching. Final per-book price / margin % is a `/plan-ceo-review` decision.
- **Auth:** Sign in with Apple **and** Google. Apple's presence satisfies the
  third-party-login rule. Cross-provider accounts are **separate** in Phase 1
  (Apple private-relay email makes email-linking unreliable).
- **Durability lives in the USER's cloud, not ours.** Server is ephemeral
  (deliver-then-delete). The translated book's durable home is the user's own
  cloud: **iCloud (CloudKit private DB)** for Apple users now; **Google Drive**
  (`drive.file`) for Google users in Phase 2. This is both the cleanest legal
  posture and avoids re-running the API on reinstall.
- **Reuse-first thin client:** the `quire-translator` Next.js server is already a
  job server (`upload / translate / status / result / job{pause,resume,cancel}`,
  per-chunk resume, `cost.ts` accounting, a `Translator` interface with
  `providers/{deepseek,fake}`). We **extend** it; we do not rebuild. The iOS app
  is a thin client — no Swift port of the core. A future **Android (Kotlin)**
  client reuses the **same backend** (the thin-client choice pays off twice).
- **Why server (not on-device):** the DeepSeek key can't ship in a public binary;
  a full-book job (80–120k words, minutes) must survive the app backgrounding.

## Architecture

```
iOS (thin client; Android/Kotlin later, same backend)   Backend (quire-translator, extended)
──────────────────────────────────────────             ──────────────────────────────────────
Sign in with Apple / Google ──id token──►  verify provider token → stable userId, session
pick own EPUB → ownership attestation
upload EPUB (background URLSession) ─────►  /api/upload  (userId-scoped; zip-hardened)
free first chapter (auto) ◄──────────────  translate spine first *content* chapter (front-matter-skipped)
buy "this book" (StoreKit 2) ──txn──────►  verify txn server-side, dedupe txn-id → entitlement(userId,sourceHash)
start full translation ──────────────────►  /api/translate  (gate: entitlement + quota + global kill-switch)
progress (poll + APNs "ready") ◄─────────  job runs server-side (resume on restart)
auto-deliver translated EPUB ◄───────────  /api/result  (userId-scoped), then server deletes (ephemeral)
import → existing LibraryStore + reader
sync to USER's cloud (iCloud/CloudKit)
                                            AI API (Western, training-excluded) ◄── key server-only, behind Translator interface
                                            long-term server state = METADATA ONLY (no book content)
```

## Backend work (extend quire-translator)

1. **Identity — Apple + Google.** Verify each provider's id token server-side
   (Apple: signature vs Apple keys, `aud`=bundle id, `iss`, expiry; Google: OAuth
   id-token verify), map to a stable `userId`, issue a session. `userId` on every
   job/entitlement. Apple and Google logins are **separate accounts** in Phase 1
   (document it; explicit linking is later).
2. **Per-user isolation invariant (legal #6).** Everything keyed by `userId`.
   **`findBySourceHash` must be scoped per-user** — today it's global
   (`lib/core/library.ts`), the cross-user-serving bright line. Make cross-user
   dedup impossible by construction.
3. **Monetization — per-book purchase + free first chapter (NOT credits).**
   - **Free first chapter:** the first *content* chapter — **skip front matter**
     (cover/title/copyright/TOC); pick the first spine item past a word-count
     threshold / nav landmark, NOT `spine[0]` (outside-voice #3). Once per
     `(userId, sourceHash)`.
   - **Paid: chapters 2+**, priced by a **length tier** detected at upload
     (e.g. <150 / 150-400 / 400+ pages → 3 StoreKit **consumable** price points),
     shown before purchase. Tier derived from the `cost.ts` token estimate so
     margin stays positive on long books.
   - **Entitlement per `(userId, sourceHash)`** (not a credit ledger). A verified
     StoreKit 2 transaction grants it; verify server-side *before* granting;
     **dedupe on transaction id** (no double-grant).
   - **Free-chapter abuse bounds:** real-first-content-chapter only +
     `(userId, sourceHash)` dedup + per-account/day rate limit + word-count cap +
     login required.
4. **Quota + cost ceiling + GLOBAL kill-switch (outside-voice #9).** Keep
   `COST_CEILING_USD` per book; add per-user/day limits **and a global daily
   spend kill-switch** — per-user caps don't bound aggregate spend across many
   throwaway accounts on the free endpoint.
5. **Ephemeral storage; durability is the user's cloud (legal — chosen posture).**
   - Source EPUB: kept only during the job, **deleted on completion**.
   - Translated EPUB: **auto-delivered immediately**; server keeps it only until
     delivered, **max ~30 days if undelivered** (device offline / storage full),
     then deleted. No long-term server library.
   - **Durable copy = the user's own cloud** (iCloud/CloudKit now; Drive Phase 2)
     + device. Reinstall restores **from the user's cloud**, not the server →
     legally cleanest AND no API re-run for Apple users. Google users before
     Phase-2 Drive sync may re-translate on reinstall-after-window (bounded, rare;
     entitlement still covers it). Lost-cloud/new-Apple-ID → recovery path (#11).
   - **Long-term server state = metadata only** (userId, sourceHash, entitlement,
     free-chapter-used, transaction id) — never book content.
6. **Paid-job robustness (outside-voice #2).** A consumable is charged at
   purchase; the job can still fail (DeepSeek down, bad chunk, ceiling). **Never
   leave a paid book undelivered:** the per-book `COST_CEILING_USD` must NOT abort
   a *purchased* job; on failure, auto-redrive, and if unrecoverable, server-driven
   refund. In Phase 1b move in-flight artifacts to **object storage (R2/S3)**
   rather than trusting a single PaaS volume (outside-voice #8).
7. **Account + data deletion & export (legal #5).** Delete account + all stored
   content + metadata; export user data.
8. **Public exposure + upload hardening (outside-voice #10).** Auth on every
   route, input validation, rate limiting, TLS, no key in logs, abuse/takedown
   switch. EPUB = untrusted zip: **size cap + sandboxed extraction + reject
   path-traversal (zip-slip) + zip-bomb guard** before parsing.
9. **Provider abstraction (outside-voice #7).** Already present in the core
   (`Translator` interface + `providers/{deepseek,fake}`). Add a Western provider
   adapter (Gemini/OpenAI/Anthropic) and make it the default; keep DeepSeek's
   `fake` provider for tests.
10. **Provider selection + quality + cost (T15, was "DeepSeek terms gate").**
    Pick the cheapest Western training-excluded model that clears the Hungarian
    literary quality bar (re-run the quality pipeline on a real book); A/B on
    cost-per-book. EU/US region + signed DPA. This replaces the DeepSeek-terms
    gate and resolves legal #3 + the China-transfer GDPR item.

## iOS work (NativRead thin client)

1. **Apple + Google login** (`AuthenticationServices` + Google Sign-In); session
   token in Keychain.
2. **Upload + ownership attestation (legal #1)** via **background `URLSession`**
   (survives backgrounding mid-upload). Affirmative "I own this book and may
   translate it for personal use" gate in the binary, not buried in ToS.
3. **Progress + push.** Poll `/api/status`; **APNs "translation ready"** is
   in-scope for 1b (not a fast-follow) — a thin client polling a multi-minute job
   can't rely on the user reopening the app (outside-voice #4).
4. **Auto-deliver → reader (NOT manual).** On ready, auto-fetch the EPUB and
   `LibraryStore.importBook(from:)` → current library + reader. Responsibility
   notice on import; **verify the import location is iCloud-backup-eligible**
   before claiming it (outside-voice #12).
5. **Per-book purchase UI.** Free first chapter shown automatically; clear
   "translate the rest — $X" with tier + price before buying. No credit balance.
6. **User-cloud sync.** Apple: **iCloud via CloudKit private DB** (durable copy in
   the user's own cloud) — Phase 1b. Google Drive (`drive.file`) — Phase 2.
   Kindle is export-only: expose the translated EPUB through the iOS share sheet
   so users can send it to Files, Mail, or Send to Kindle. Do **not** promise
   Kindle reading-position/highlight sync; there is no reliable public Kindle API
   for third-party Whispersync-style writes.
7. **Account deletion + data export UI (legal #5)** + a **lost-entitlement
   recovery/support path** (outside-voice #11).
8. **AI-provider disclosure (legal #4)** pre-first-translation (names the chosen
   Western provider) + accurate App Store privacy labels; **metadata/copy scrub**
   of any "get/read any book" wording (legal #2). No acquisition/discovery features.
9. **Live privacy policy + ToS URLs** with warranty/indemnity + named
   sub-processors at submission (legal #7).

## Phasing

- **Phase 1a — validate flow + demand (STATELESS, no durability infra).**
  A single **stateless `translate-one-chapter` endpoint** (a free chapter is
  seconds and ephemeral — it does NOT need volumes/resume/retention/auto-delivery)
  + Apple/Google auth + ownership attestation + front-matter-skipped free chapter
  + DeepSeek disclosure + account deletion + **global spend kill-switch**. The
  free chapter IS the demand signal. Fastest path to the real answer.
- **Phase 1b — paid product (full job machinery appears here).** Full job
  lifecycle (resume, object storage), auto-deliver + APNs + background upload,
  per-book StoreKit + entitlement + txn-dedupe, **paid-job robustness**
  (refund/redrive, ceiling can't abort a paid job), iCloud/CloudKit durability,
  **cross-chunk name/term glossary as a quality gate** (outside-voice #6 — the
  first paid novel exposes inconsistent names otherwise), recovery path.
  (1a + 1b = the App-Review-and-legal-gate-passing MVP. Reader stays as-is.)
- **Phase 2 — UX/reach.** Bilingual original↔translation toggle, **Google Drive
  sync**, editable character-name glossary UI, target-language TTS (`TODOS.md`).
- **Phase 3 — EU readiness.** Largely RESOLVED by the Western-provider switch (no
  China transfer). Remaining: standard GDPR hygiene (DPA with the provider + host,
  EU/US region selection, privacy policy) — no Chapter V China-transfer mechanism
  needed.
- **Future — Android (Kotlin) thin client** reusing the same backend.

## Explicitly out of scope (Phase 1)

- Swift/Kotlin port of the translation core (thin client suffices; core stays
  server-side and is shared by the future Android client).
- Cross-user / shared translated library (legal bright line — never).
- Cross-provider account linking (Apple↔Google) — separate accounts for now.
- External payment for the purchase (IAP-only, Guideline 3.1.1).
- Google Drive sync, bilingual reader toggle, editable glossary UI (Phase 2).

## Open risks

- **Provider quality vs cost (T15)** — a cheap Western model must clear the
  Hungarian literary bar; re-validate on a real book before committing. Mitigated
  by the `Translator` iface (A/B providers) + the existing quality pipeline.
- **Paid-but-undelivered** — the single most damaging failure; §6 must be airtight.
- **App Review 5.2** pattern-match — mitigated by visible attestation + "own book"
  framing + "AI-translated" UI copy with the provider disclosed in the privacy layer.
- ~~Pricing/margin~~ — RESOLVED by CEO review (D4): value-anchored length ladder,
  $2.99–$11.99; API cost is cents so margin is healthy at every tier.
- ~~China data-transfer~~ — RESOLVED by the Western-provider switch.

## What already exists (reuse, don't rebuild)

- `quire-translator` core: `epub`, `chunker`, `markup`, `glossary`, `translator`
  (with `Translator` interface + `providers/{deepseek,fake}`), `job` (per-chunk
  resume), `cost.ts` (token accounting), quality pipeline. Framework-agnostic.
- `quire-translator` server: `upload/translate/status/result/job{pause,resume,
  cancel}` routes, in-memory job registry, Dockerfile.
- NativRead iOS: `LibraryStore.importBook(from:)`, WKWebView reader, library/UI.
- Gaps the plan adds (not in quire-translator): auth, per-user isolation,
  StoreKit/entitlements, ephemeral+user-cloud storage, PaaS durability, public
  hardening. quire-translator's file/in-memory model is household-LAN; it does
  NOT transfer to public PaaS unchanged (see Arch review finding #3).

## UI / Design spec (from /plan-design-review, 2026-06-30)

All translator screens ride the existing editorial system (`NativRead/DesignSystem/`):
**BrandPalette** (paper `#F7F3EC` / ink `#1A1714` / russet `#9A3B2E`), **Typography**
(Cormorant Garamond display, Crimson Pro title/body, tracked SF eyebrow/meta),
**Spacing** scale + 44pt targets. No parallel visual language; login/purchase must NOT
look like generic system/IAP sheets. Classify: APP UI (calm surface hierarchy, utility
copy). Copy voice: plain, large, reassuring, for the 50+ non-native reader; UI says
"AI-translated" (provider named only in the privacy layer).

### Per-screen information hierarchy

- **Login:** brand mark → one line on why sign-in is needed → Sign in with Apple
  (primary) + Google. No happy-talk.
- **Ownership attestation (D5 — per book, at each upload):** affirmative "I own this
  book and may translate it for personal use" gate before each upload. Single clear
  checkbox + confirm; visible, not buried. Reviewer-facing 5.2 artifact.
- **Free first chapter:** the chapter, read in the existing reader. Buy affordance
  present from the first moment (see purchase entries below).
- **Purchase (D4 + refinement — three entry points, never a forced scroll):**
  (1) a **persistent, quiet buy entry** in the book view available from the start, so
  a decided buyer or a returning reader (e.g. book 3 of a series, trusted from book 2)
  can purchase immediately without consuming the free chapter; (2) a **mid-chapter
  reachable** buy affordance (someone sold after a few lines taps once); (3) a
  **prominent contextual prompt at the natural end of the free chapter** ("Loved
  chapter 1? Translate the whole book — $X"). All three show the length tier + exact
  price + what's translated BEFORE purchase (legal #8).
- **Progress (D3 — leave-and-notify primary):** lead with reassurance — "You can close
  the app. We'll notify you when your book is ready." Show chapters-done + estimated
  time for those who stay. Calm editorial styling, not a system spinner. Fallback copy
  if notifications are denied ("Reopen the app to check progress").
- **Auto-deliver → import:** on ready, the book appears in the existing library with a
  brief responsibility notice; opens in the existing reader.

### Interaction state table

```
SCREEN            | LOADING            | EMPTY/FIRST-TIME        | ERROR                         | SUCCESS              | PARTIAL
------------------|--------------------|-------------------------|-------------------------------|----------------------|------------------
Login             | spinner on tap     | first-run explainer line| "Sign-in failed, try again"   | → upload             | —
Upload+attest     | upload progress    | "Pick an EPUB you own"  | bad file / too large message  | → free chapter       | resumable upload (bg)
Free chapter      | "Translating ch.1" | —                       | "Couldn't translate, retry"   | chapter renders      | —
Purchase          | "Confirming…"      | —                       | StoreKit fail → clear retry   | → full job starts    | —
Progress          | est. time + chapters| —                      | job failed → auto-redrive msg; if unrecoverable → refund notice | "Ready!" notify | N of M chapters
Auto-import       | "Adding to library"| —                       | storage-full → guidance       | book in library      | —
```
Every error is user-visible with a recovery path; **paid-but-undelivered** surfaces an
explicit "we're retrying / you'll be refunded" message, never a silent failure.

### Accessibility floor (50+ persona — required, not deferred)

Dynamic Type on all translator chrome; 44pt minimum targets; VoiceOver labels on every
control (esp. the attestation checkbox and buy buttons); contrast ≥ 4.5:1 on body. The
deeper VoiceOver-over-the-reader-page pass stays deferred (TODOS), but this floor ships.

## Implementation Tasks
Synthesized from this review's findings. P1 blocks ship; P2 same branch; P3 follow-up.

- [ ] **T1 (P1, human ~1d / CC ~2h)** — backend — Per-user scope `findBySourceHash`
  - Surfaced by: Arch/legal #6 — global in `lib/core/library.ts` (cross-user bright line)
- [ ] **T2 (P1, ~2d / ~3h)** — backend — Apple+Google id-token verify → userId + session (separate accounts)
- [ ] **T3 (P1, ~1d / ~2h)** — backend — Stateless `translate-one-chapter` (1a), front-matter-skipped (outside-voice #5/#3)
- [ ] **T4 (P1, ~1d / ~3h)** — backend — Global daily spend kill-switch on free endpoint (outside-voice #9)
- [ ] **T5 (P1, ~1d / ~2h)** — backend — EPUB upload zip hardening: size cap, sandbox, zip-slip, zip-bomb (outside-voice #10)
- [ ] **T6 (P1, ~2d / ~3h)** — backend — Paid-job robustness: ceiling can't abort paid job; refund/redrive (outside-voice #2)
- [ ] **T7 (P1, ~2d / ~3h)** — backend — StoreKit verify + entitlement(userId,sourceHash) + txn-id dedupe
- [ ] **T8 (P1, ~1d / ~2h)** — backend — Ephemeral storage: delete source on done; deliver-then-delete; 30d cap; metadata-only
- [ ] **T9 (P1, ~1d / ~2h)** — backend — Account + data deletion & export (Apple 5.1.1(v))
- [ ] **T10 (P1, ~2d / ~3h)** — ios — Apple+Google login; attestation gate; background-URLSession upload
- [ ] **T11 (P1, ~2d / ~3h)** — ios — Auto-deliver→import; APNs ready; storage-full; responsibility notice (outside-voice #4/#12)
- [ ] **T12 (P1, ~1d / ~2h)** — ios — Per-book purchase UI (tier+price before buy); free chapter auto-shown
- [ ] **T13 (P2, ~2d / ~3h)** — ios — iCloud/CloudKit private-DB durable sync (Apple)
- [ ] **T14 (P2, ~1d / ~2h)** — backend — Cross-chunk name/term glossary quality gate, 1b (outside-voice #6)
- [ ] **T15 (P1, ~1-2d / ~half-day)** — backend — Select Western training-excluded provider (default Gemini Flash-class), add adapter, re-validate Hungarian quality + cost A/B (resolves legal #3 + China transfer)
- [ ] **T16 (P1, ~1d / ~1h)** — ios — DeepSeek disclosure + App Store labels + metadata scrub + privacy/ToS URLs
- [ ] **T17 (P3, ~0.5d / ~1h)** — backend — Lost-entitlement recovery/support path (outside-voice #11)
- [ ] **T18 (P1, ~0.5d / ~1h)** — backend — First-party conversion funnel events in Postgres (free-chapter-completed → purchase-started → purchase-completed; segment by length tier + target language)
  - Surfaced by: CEO §8 / D5 — compressed MVP (D1) makes the funnel the only demand signal
  - **Eng D4:** funnel writes ride the SAME rate-limit + global kill-switch as the free endpoint (T4); rows are metadata-only (no book content); raw events pruned/aggregated on a retention window so abuse can't balloon the table or skew conversion. Test: event emitted on each transition.
- [ ] **T19 (P1, ~1d / ~1-2h)** — backend — Backend-only Sentry-class error monitoring; alert on paid-but-undelivered; disclose as sub-processor (legal #7). iOS stays SDK-free.
  - Surfaced by: CEO §8 / D6 — paid-but-undelivered is the most damaging failure; needs fast paging
  - **Eng D2 (P1):** explicit scrub — `sendDefaultPii:false`; `beforeSend` strips request bodies (= book text); deny-list env + headers (the AI provider API key); allowlist only safe fields (error type, job id, hashed userId). Test asserts no book text and no key appear in the captured payload. The default config is unsafe and MUST NOT ship.
- [ ] **T20 (P1, ~0.5d / ~1h)** — backend — Pricing: register 5-6 length-tier StoreKit consumables (D4 ladder); pick tier at upload
  - Surfaced by: CEO §9 / D4 — ladder replaces 3 tiers; continuous pricing barred by IAP
  - **Eng D3:** tier = pure function of the parsed EPUB's word/char count (a STABLE input, not a variable live estimate), computed once at upload and FROZEN per `(userId, sourceHash)`; the price shown before purchase (legal #8) IS the SKU charged (Apple 3.1.1). Test: same book → same tier every time.
- [ ] **T21 (P1, ~1d / ~2h)** — ios — Progress screen, leave-and-notify primary (D3): reassurance copy + chapters-done/est-time + notifications-denied fallback; editorial tokens
  - Surfaced by: Design P2/P3 — multi-minute wait for the 50+ persona
- [ ] **T22 (P1, ~1d / ~2h)** — ios — Three-entry purchase UX (D4): persistent buy entry from start + mid-chapter affordance + end-of-free-chapter prompt; tier+price+scope shown pre-buy; no forced scroll
  - Surfaced by: Design P3 — magic-moment conversion + returning/decided buyers
- [ ] **T23 (P1, ~0.5d / ~1h)** — ios — Per-book ownership attestation gate at each upload (D5), single clear checkbox+confirm, editorial styling (legal #1 reviewer-facing)
  - Surfaced by: Design P1 — 5.2 survival artifact
- [ ] **T24 (P1, ~1d / ~2h)** — ios — Translator screens on BrandPalette/Typography/Spacing + interaction state table (all states user-visible, paid-but-undelivered non-silent) + 50+ a11y floor (Dynamic Type, 44pt, VoiceOver, contrast)
  - Surfaced by: Design P2/P4/P5/P6 — editorial fit, full state coverage, accessibility
- [~] **T25 (P1, ~0.5d / ~1h)** — ios+backend — EU AI Act Art 50 transparency (applies 2026-08-02). **iOS visible label: DONE** 2026-07-06 — imported translations read "(AI Hungarian preview/translation)" + "AI · HU" library badge. **Remaining (backend):** machine-readable "AI-generated (machine translation)" marker in the delivered translated EPUB's OPF metadata, preserved on re-export.
  - Surfaced by: legal-posture.md §EU AI Act (2026-07-06 compliance pass); pairs with T16's disclosure copy

## Worktree parallelization

| Lane | Steps | Depends on |
|------|-------|------------|
| A (backend core) | T1, T3, T5, T8 | — |
| B (backend money/auth) | T2 → T7 → T6 | T2 before T7 |
| C (backend safety) | T4, T9 | — |
| D (iOS) | T10 → T12 → T11 | backend endpoints (A/B) |

Lanes A, B, C touch `lib/` / `app/api/` (same repo, coordinate); D is the iOS repo
(independent until it integrates endpoints). Launch A+B+C with care on shared
`lib/core/`; D can start on auth/upload UI in parallel.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | CLEAR | SELECTIVE_EXP: 5 proposals, 3 accepted (compressed MVP, kept iCloud, funnel+Sentry), 2 deferred (multi-lang, learner mode); pricing resolved |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 2 | CLEAR | Run 1: 5 findings + 12 outside-voice, dispositioned. Run 2 (post-CEO scope): 3 findings on new scope, all folded — Sentry scrub (T19a), tier determinism (T20a), funnel bounding (T18a) |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR | score 3/10 → 9/10; 3 decisions (progress leave-and-notify, 3-entry purchase, per-book attestation) + full UI/design spec added |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **OUTSIDE VOICE (eng review, Claude subagent):** 12 findings; 2 escalated to product
  decisions, 10 folded as fixes.
- **OUTSIDE VOICE (CEO + eng re-review):** SKIPPED — Codex not installed; subagent
  fallback not auto-spawned this session. Re-run with `npm install -g @openai/codex`.
- **CROSS-MODEL:** no tension at eng review; CEO review added strategy decisions (D1
  compressed MVP, D4 pricing ladder, D5 funnel, D6 monitoring) — none contradict eng.
- **VERDICT:** CEO + ENG + DESIGN CLEARED — ready to implement as a **compressed paid
  MVP** (D1, no longer 1a-first), **Hungarian-only** (D3.1), with the UI/design spec
  above. Legal gate PASS WITH CONDITIONS (see `legal-posture.md`); provider selection
  (T15) is an external gate before launch, not a code blocker.

NO UNRESOLVED DECISIONS
