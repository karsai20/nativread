# NativBook launch blueprint — GTM, compliance, features, GitHub, backend security

Status: REVIEWED 2026-07-07 (/plan-ceo-review, SELECTIVE EXPANSION — see the
GSTACK REVIEW REPORT at the end; scope decisions persisted in
`~/.gstack/projects/karsai20-nativread/ceo-plans/2026-07-07-launch-blueprint.md`).
Consolidates and extends:
[`legal-posture.md`](./legal-posture.md) (legal/AI Act — authoritative),
[`translator-plan.md`](./translator-plan.md) (engineering plan + task list T1–T25),
[`onboarding-strategy.md`](./onboarding-strategy.md) (first-run flow),
[`../TODOS.md`](../TODOS.md) (deferred work). Where those docs decide something,
this doc points at them instead of restating.

**Branding:** the product's public name is **NativBook** (decided 2026-07-07,
gated on the name-clearance check in §3). The repo/app internally remains
NativRead until the P3 rename sweep (TODOS). Older docs say Quire.

---

## 1. Positioning & market

**One-liner:** *Translate the books you own into your language with AI — at
literary quality — and read them in a calm, beautiful reader.*

**The competitive truth (corrected 2026-07-07):** AI EPUB translation is a
crowded category — BookTranslator.ai, Immersive Translate, eBook Translator
(iOS), Belin Doc, O.Translator, open-source pipelines. Their existence
**validates demand**. None of them combines what NativBook is: **validated
literary quality per language** (a quality pipeline gates every launch
language — generic tools ship raw MT), **an integrated calm reader** (no
upload-download-sideload loop), **a 50+ persona UX** (people who will never
use a web upload tool), **a clean legal & AI-Act posture** (ephemeral server,
user-owned cloud copy, honest AI labeling), and **per-book pricing** (no
subscription anxiety). The moat is the combination — fit and trust, not raw
capability. Track the tool landscape in `docs/competitors/` (add a
translator-tools file; refresh at each major release).

**The objection to answer everywhere ("why not a free web tool?"):**
1. Quality: web tools ship raw machine output; NativBook ships only languages
   that pass a literary quality bar — see the public quality-proof page (§3).
2. Comfort: no export/import juggling — the book appears in your library,
   readable, with your typography, progress, and highlights.
3. Trust: your book is not retained on anyone's server (deliver-then-delete);
   the durable copy lives in *your* cloud; the AI provider never trains on it.

**Primary persona (the wedge):** 50+ Hungarian reader. **Launch hook:**
*continue the book series you love in your own language* — Hungarian
publishers abandon series mid-way; NativBook finishes them for you (of the
books you own).

**Buyer insight:** the buyer is often the reader's **adult child** buying for
a parent. Channel consequence: market on the children's channels too
(Instagram/Reddit/tech press), not only the parents' (Facebook). No gifting
*mechanics* — cross-account delivery would break per-user isolation
(legal-posture principle 2); the child buys on the parent's device or shares
their family know-how, not files.

**Secondary personas:** language learners (bilingual aligned reading is the
Phase 2 learner story — market it only as *coming*, never as a launch
feature) and "just readers" (free tier; the rating base and referral pool).

**Anti-positioning (legal #2 — never say):** anything implying users can
*find, get, or unlock* books. Copy is always "translate books you already
own." Never encourage sharing translated files (see §3 Stage 4).

**DRM reality (risk, accepted):** many users' "owned books" are print or
DRM-locked and not importable. Onboarding must set expectations honestly
("bring your DRM-free EPUB/PDF/TXT") **without ever pointing at acquisition
sources** (App Store 5.2). Counsel agenda covers how far guidance may go.

## 2. Pricing & monetization

Decided (CEO D4, translator-plan.md) — restated for the GTM view:

- **Free forever:** the reader itself (import EPUB/PDF/TXT/AZW3, themes,
  typography, Define, highlights). The free reader is the acquisition engine.
- **Free trial:** first content chapter of any book, AI-translated, once per
  book per user.
- **Paid:** per-book consumable IAP, length-tiered ladder $2.99–$11.99
  (6 pre-registered SKUs, tier frozen at upload). No subscriptions, no credit
  ledger, no external payments (Guideline 3.1.1).
- **Margin (task, pre-SKU-freeze):** model the REAL per-book cost — retries,
  weak-chunk re-runs, glossary passes, refunds, Apple's 15–30% — not just raw
  token cost, before registering the SKU ladder. "Cents per book" is the raw
  API floor, not the business cost.

Why per-book beats subscription for this persona: the 50+ reader buys *a
book*, not a plan; zero recurring-billing anxiety; price anchors against a
paperback.

## 3. Launch sequencing & gates

**Art 50 timing, stated precisely:** 2026-08-02 is the date the EU AI Act
transparency obligations *apply from* — a compliance-before-any-public-
availability gate, NOT a launch-by deadline. Launching later is fine;
launching anything public without the marker after that date is not.

**Sequencing decision (2026-07-07):** counsel starts NOW with a fixed agenda
(personal-use-derivative under operator-stores-copy; trademark filing;
AZW3-import optics; DRM-guidance limits; free-chapter derivative question;
abuse/takedown posture; **HU/DE/ES national variance of the private-adaptation
question** — the adaptation right is not EU-harmonized, so the DE/ES launch
answer can differ from the Hungarian one) and is asked for a **week-1
preliminary risk read**. Research input for the brief:
[`legal-research-2026-07-07.md`](./legal-research-2026-07-07.md) (case-law map:
VCAST vs Austro-Mechana; competitor enforcement reality).
Backend, T25, and language validation proceed immediately; **website build,
SKU registration, and press outreach wait for the preliminary read** (not for
full sign-off). If counsel reshapes the model, the expensive-to-redo public
assets haven't been built yet.

**Stage 0 — now → backend Phase 1a/1b complete (in progress).**
Build per translator-plan.md T1–T25. Nothing public.

**Stage 1 — hard gates (all green before ANY public availability):**

| Gate | Source | Status |
|---|---|---|
| **NativBook name clearance** — App Store search + EUIPO/WIPO/USPTO knock-out + domain check, BEFORE any public asset | CEO review Q2 | open — do this week |
| EU AI Act Art 50(2) machine-readable EPUB marker **+ robustness spec**: marker survives re-export/Send-to-Kindle where technically feasible; automated validation test; EPUB is the only translated output format (previews are in-app renders of it) | legal #9 / T25 | backend half open |
| Visible "AI-translated" label | T25 iOS half | ✅ done 2026-07-06 |
| Ownership attestation in-flow | legal #1 / T23 | open |
| Privacy labels + provider disclosure + policy/ToS URLs | legal #4, #7 / T16 | drafts done 2026-07-07 (`docs/legal/`, HU+EN); placeholders pend T15/host choices |
| Account + data deletion & export | legal #5 / T9 | open |
| Server-side StoreKit verify + txn dedupe | legal #8 / T7 | open |
| Per-user isolation by construction | legal #6 / T1 | done in Phase 1a work |
| OSS licenses screen (ZIPFoundation MIT) | TODOS P2 | open |
| **External: counsel preliminary read (week 1) → full sign-off before commercial launch** | legal review condition + CEO C-Q5 | **founder decision 2026-07-07: proceeding WITHOUT counsel for now** — accepted risk; agent-drafted doc pack in `docs/legal/` + research annex prepared so a later counsel review is a cheap read-through, not a from-scratch engagement. Gate stays on the books for the commercial phase. |

**Launch languages (supersedes 2026-06-30 "Hungarian-only" — CEO D4/C):**
multi-language at launch, with a RAISED gate per language:
- full quality-pipeline run on **one complete real novel**, judged against the
  same thresholds that approved Hungarian, **plus one native-speaker read of
  sample chapters** (recruit via communities/Upwork, ~€50–100/language);
- founder records a dated go/no-go per language;
- **pass → launch picker; fail or pending → in-app waitlist only. Never
  "beta", never "ships with caveats", no exception under date pressure.**
- Candidates: German, Spanish (+ optionally one more from desk research).
- Storefronts at launch: **EU only**; worldwide is a post-launch expansion.
  Marketing push stays Hungary-first. Messaging never pre-announces a
  language before its dated go/no-go.

**Milestones (targets; the sequence is the contract):** counsel + name
clearance now → T25 marker + robustness test ~1 week → DE/ES pipeline runs +
native reads ~2 weeks → website live (soft-gated on counsel read + clearance)
~3 weeks → TestFlight (1–2 weeks) → submission when gates are green.
Contingency: a name-clearance conflict STOPS public-asset work until a new
name clears — that is the point of the gate.

**Stage 2 — private beta (TestFlight), 1–2 weeks.**
- 20–50 testers from the target persona. Hungarian UI, real books, sandbox
  purchases. **TestFlight validates UX, not willingness to pay** — sandbox
  conversion is not a demand signal; real demand is read from the first two
  weeks of live sales (T18 funnel).
- Exit criteria: zero paid-but-undelivered incidents (T19 alerting),
  crash-free ≥ 99.5%, the funnel instrumentation demonstrably recording.
- Website is a SOFT dependency here (testers get the app link directly); it
  is a HARD dependency for Stage 3 press outreach.

**Stage 3 — App Store launch (soft).**
- Submit with reviewer notes pre-empting Guideline 5.2: the attestation gate,
  "user's own books" model, no acquisition features. Screenshots show the
  attestation and the AI label.
- Fully localized hu; EU storefronts. No acquisition spend; watch the organic
  funnel for 2 weeks.
- App Store product page: Hungarian keywords ("könyv fordító", "e-könyv
  olvasó", "angol könyv magyarul") — near-zero competition for translation
  terms.

**Stage 4 — marketing push (only after the live funnel proves conversion).**
Channels for the 50+ Hungarian persona AND the child-buyer, cheapest first:

1. **Hungarian book communities:** moly.hu, Hungarian book-club Facebook
   groups (the 50+ persona), plus Reddit r/hungary / Instagram for the
   child-buyer angle ("add vissza a szüleidnek az olvasást"). Founder-voice
   posts, not ads.
2. **The website** (see below): landing + quality proof + planned languages +
   press kit — the link every post and pitch points at.
3. **Hungarian tech/book press:** Telex, 444, Qubit, Könyves Magazin — solo
   Hungarian builder ships literary AI translation; press kit ready on the
   website before outreach.
4. **Paid (last):** Apple Search Ads on Hungarian keywords only after LTV is
   known.

Note (changed 2026-07-07): translated-EPUB export exists for the **user's own
devices** (Files, their own Kindle). It is NOT a growth channel and marketing
must never encourage sharing translated files — that would contradict the
per-user-isolation posture. The EPUB colophon line ("AI translation by
NativBook") is provenance and the Art 50 marker's human-readable companion,
not advertising.

**The website (CEO D5, soft-gated on counsel read + name clearance):**
one static, no-backend site, four pieces: (1) landing with the promise,
(2) **quality-proof page** — one public-domain excerpt shown three ways
(original / NativBook / generic MT), with an honest note that a
public-domain sample demonstrates style, not modern-prose rights; (3)
planned-languages display (read-only — demand capture is in-app, §6); (4)
press-kit page. Rides the editorial design system (paper/ink/russet, existing
typography) so site and app read as one product. No PII, no forms. Run
`/plan-design-review` before building it. **Hosting/deploy (eng D3):** static
host (GitHub Pages / Cloudflare Pages class), deploy-on-push from its own
repo, TLS automatic; the **domain is purchased as part of the §3
name-clearance step** — no domain before the name clears.

**Stage 5 — expansion (post-PMF, per TODOS):** next languages from the
waitlist evidence (same raised gate each); learner inline-gloss mode; Android
thin client on the same backend; storefronts beyond the EU; TTS
"Hungarian audiobook" play — Hungarian audio of untranslated English books,
the strongest expansion story.

## 4. Metrics (what "working" means)

T18 first-party funnel (Postgres, no third-party analytics) plus app-side:

| Metric | Target | Why |
|---|---|---|
| Onboarding → first book imported | > 60% | reader value works |
| Import → free chapter started | > 30% (translate-intent users) | the hook lands |
| Free chapter completed → purchase | > 8–12% (live sales, not TestFlight) | the business exists |
| Paid-but-undelivered | 0 (page on any) | trust is the product |
| D30 retention (readers) | > 25% | the reader is genuinely good |
| App Store rating | ≥ 4.5 | 50+ persona reads reviews |
| Language waitlist counts | informational | picks language #4+ |
| Review prompts shown → not dismissed | informational | prompt timing works |
| **Failure buckets** (import-failed / drm-blocked / format-unsupported / moderation-refused / chapter-detection-wrong) | informational denominator | makes the kill signal interpretable |

Kill/pivot signal: if free-chapter → purchase < 3% after copy/pricing
iteration, the translation wedge is wrong — fall back to the reader + learner
path. **Denominator control (eng D12 / Codex #6):** read conversion against
*attempted-and-eligible* users — the T18 failure buckets exist so a DRM-heavy
or import-broken cohort can't masquerade as a pricing/wedge failure. Do not
act on the kill signal without the buckets alongside it.

**Rating mechanism (CEO D3.3):** request a review (SKStoreReviewController)
only at peak-happiness — after the user finishes their first translated book
(or their third finished book for just-readers). Never after an error, never
during onboarding. Unhappy paths route to a support intercept (mail sheet
with a copyable support address as fallback), so complaints go to email, not
the store.

## 5. Legal & EU AI Act compliance (summary — `legal-posture.md` is authoritative)

- **Classification:** limited-risk AI system; only Art 50 transparency
  applies; GPAI-model duties sit with the API provider — but WE are the
  provider of the translation *system* and own its Art 50 duties (that is
  what T25 implements). Obligations apply from **2026-08-02** (see §3 for
  what that date does and does not mean).
- **The two Art 50 duties:** machine-readable marker in every delivered/
  exported translated EPUB (T25 backend half + robustness test — ship next),
  and visible "AI-translated" labeling (done). EPUB is the only translated
  output format; the marker + colophon travel with every export.
- **Marker spec (eng D2, 2026-07-07; RECORDED 2026-07-09, E1 done):** the
  **EC Code of Practice on Transparency of AI-Generated Content (final,
  published 2026-06-10)** was read: it prescribes marking *mechanisms*
  (multi-layer machine-readable metadata; C2PA for signed manifests) but
  names **no property vocabulary for text publications**. The pinned spec
  therefore expresses the industry machine-readable value through EPUB 3's
  package-prefix mechanism, layered per the CoP's ≥2-layer guidance:
  1. `<package prefix="iptc: http://iptc.org/std/Iptc4xmpExt/2008-02-29/">`
     + `<meta property="iptc:DigitalSourceType">http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia</meta>`
  2. `<dc:description id="nativbook-ai-marker">AI-generated content: machine
     translation from {source} to {target} by NativBook (EU AI Act Art 50).</dc:description>`
  3. `nativbook-colophon.xhtml` appended to manifest + spine (human-readable
     companion; survives OPF-stripping conversions).
  Implemented in `quire-translator/lib/core/ai-marker.ts` (injected in
  `job.ts` before every delivery, full and sample; idempotent; fails loudly
  on malformed OPF). Validation: `test/ai-marker.test.ts` asserts the exact
  spec + re-zip round-trip survival; the iOS import half is
  `EPUBParserTests.testParsesArt50AIMarkedEPUB`. C2PA signed-manifest
  layer: deferred until a C2PA↔EPUB binding exists (CoP names none — the
  CoP's signed-metadata commitment is written for signatories; we are not
  one, Art 50 itself requires effective+interoperable marking, which the
  IPTC value provides). Timing note: the May 2026 AI Omnibus grants
  pre-2026-08-02 systems until 2026-12-02 for the machine-readable half —
  irrelevant here (we launch after Aug 2), the gate stays hard.
- **GDPR:** Western provider with EU/US region resolved the hard part.
  Remaining hygiene: DPA with AI provider + host + Sentry-class monitor,
  privacy policy naming all three, data-subject export/delete (T9). The
  language waitlist stays in-app and metadata-only — deliberately no email
  list, no new PII store before launch.
- **Copyright:** per-user isolation is the bright line — enforced by
  construction (T1) and covered by a regression test. Residual risk
  (operator-stores-the-copy) is accepted-with-counsel-review; the counsel
  agenda (§3) also covers AZW3 optics, DRM-guidance limits, and the
  free-chapter derivative question.
- **App Store:** the MUST-FIX ★ items are the review-survival artifacts.

Compliance calendar: counsel engagement → now (week-1 preliminary read);
Art 50 backend marker + test → this sprint; DPAs + policy URLs → before
external TestFlight; everything else → before submission.

## 6. Feature roadmap — comfort + translation

Principle (onboarding-strategy.md): three jobs — translate, learn, just read.
Task IDs refer to translator-plan.md / TODOS.md.

**Now (launch-blocking, translation job):**
- Remaining T-tasks of Phase 1a/1b, led by: T25 backend marker + robustness
  test, T23 attestation, T16 disclosure, T7 StoreKit, T9 deletion/export,
  T11 auto-deliver + APNs.
- **Safety-filter risk (new, 2026-07-07):** provider moderation can refuse or
  degrade literary sex/violence/politics mid-book — a paid-but-undelivered
  generator. Mitigate: (a) moderation behavior on literary content becomes a
  T15 provider-selection criterion (test with a spicy public-domain text),
  (b) a mid-book refusal triggers the T6 redrive-then-refund path, never a
  silent partial delivery, (c) **free-chapter refusals (eng D4):** T3
  classifies provider refusal separately from transient failure — distinct
  non-retry copy ("this book can't be translated automatically"), the
  free-chapter credit is NOT consumed, each refusal logged as a T15 data
  point + a T18 failure event. A refusal is deterministic; a "retry" loop
  would re-fail identically while re-burning API cost.
- Streamed upload/download + background URLSession (TODOS P1/P2).
- **Multi-language launch machinery (CEO D4/C):** pipeline runs + native
  reads for DE/ES; picker lists passed languages only — **hardcoded in-app
  list (eng D7;** server-driven list is a named TODOS upgrade path — new
  languages are deliberate release events, not hotfixes). **Schema (eng D9):**
  entitlement, tier-freeze, and job identity are keyed
  `(userId, sourceHash, targetLanguage)`; the free trial stays per
  `(userId, sourceHash)` — one free taste per BOOK, any language, so the
  abuse bound doesn't scale with language count.
- **Entitlement restore by re-upload (eng D11, promoted from T17/P3 to P1):**
  consumable IAPs have no Apple-side restore — the server entitlement row IS
  the restore. Re-uploading the same `(sourceHash, targetLanguage)` finds the
  entitlement and re-delivers/re-runs at no charge; tests assert no
  double-charge/double-grant; the purchase UI states the guarantee. Exotic
  recovery (new Apple ID) stays the P3 support path.
- **In-app language waitlist (CEO D3.4/Q1A):** "Other language" picker →
  `(userId, language)` metadata row via the T18 plumbing; dedupe per user;
  rides existing rate limits. One SQL count is the dashboard.
- **Review-prompt policy (CEO D3.3):** as specced in §4; unit-tested
  (fires once, never on error paths — `ReviewPromptPolicyTests`).
- Onboarding first-run flow as specced (intent branching, contextual
  permission asks, payment never in onboarding, DRM-reality expectation
  copy per §1).

**Comfort (the reader is the retention engine — ship alongside launch):**
- 50+ accessibility floor everywhere: Dynamic Type, 44pt targets, ≥4.5:1
  contrast, VoiceOver labels (T24) — device-tested on the reading and
  purchase flows, then the deep VoiceOver-over-WKWebView pass (TODOS).
- Progress screen "leave and notify" pattern (T21).
- Reading comfort staples the persona expects (verify all exist, gap-fill):
  brightness/theme per book, font size memory, page-turn preference. Every
  new surface rides BrandPalette/Typography/Spacing tokens.

**Next (post-launch, sequenced by funnel evidence):**
1. **Bilingual original↔translation aligned reading** (Phase 2) — indexed
   sentence alignment, tap-to-reveal the original; the learner story and the
   feature that turns every purchase into a language-learning asset. Marketed
   pre-launch only as "coming".
2. Editable character-name glossary UI (server glossary T14 ships at launch).
3. Google Drive durability for Google-login users (Phase 2).
4. Learner inline-gloss "reading level" mode (TODOS P2).
5. Target-language TTS — the "Hungarian audiobook" expansion (TODOS).
6. Next translation languages from waitlist evidence (same raised gate).
7. ES/DE UI locales + dictionary packs (TODOS deferred-localization block).

**Explicitly never (legal bright lines):** book acquisition/discovery, shared
translated library, gifting mechanics across accounts, external payments,
undisclosed egress, marketing that encourages sharing translated files.

## 7. GitHub best practices (both repos: `nativread`, `quire-translator`)

Current state is a solo-builder flow with PRs — keep that, add the cheap
protections that matter at public-launch stakes:

**Branch & merge discipline**
- `main` protected: require PR, require status checks green, no force-push,
  no direct pushes (solo repos too — it prevents accidents, costs nothing).
- Short-lived feature branches (`feat/…`, `fix/…`, `compliance/…` as already
  practiced); squash-merge; conventional-commit titles.
- Delete merged branches automatically (repo setting).

**CI (GitHub Actions) — minimum viable, per repo:**
- nativread: `xcodegen generate` + build + **unit-test target only** on the
  simulator destination on every PR (eng D5: skip XCUITests via a CI test
  plan — simulator UI tests are wedge-flaky on shared runners and macOS
  minutes bill 10× on private repos; a flaky required check is worse than
  none). UI tests remain the local pre-release ritual. Cache
  SwiftPM/DerivedData.
- quire-translator: `bun install --frozen-lockfile`, typecheck, `bun test`,
  lint — on every PR. Add `bun audit` as a non-blocking job first, blocking
  once clean.
- Pin third-party actions by commit SHA, not tag, and set the workflow-level
  `permissions:` block to `contents: read` by default — the two changes that
  neutralize most Actions supply-chain risk.

**Secrets & sensitive data**
- Repo-level secret scanning + push protection ON. Gitleaks in CI as a
  second net.
- Never commit: AI provider keys, Apple private keys (`.p8`), StoreKit
  shared secrets, `.env*` (only `.env.example` with placeholders).
- If a key ever lands in a commit: rotate first, then scrub history.

**Dependencies**
- Dependabot (or Renovate) for npm + GitHub Actions ecosystems, weekly,
  grouped minor/patch. Pin ZIPFoundation to an exact version in `project.yml`.
- Lockfiles always committed; CI installs frozen.

**Repo hygiene for going public-facing**
- No book content, user data, or non-public-domain fixtures in either repo.
- `SECURITY.md` with a vulnerability-report contact.
- Tag releases matching App Store builds; CHANGELOG discipline continues.

## 8. Backend security hardening (quire-translator going public)

The plan's security tasks (T4, T5, T19 scrub, isolation T1) are necessary;
this is the consolidated checklist, ordered by blast radius. **Authority (eng
D6): on any conflict, `translator-plan.md` task specs are authoritative for
implementation detail — this section is the ordered checklist view.**

**Identity & session (T2 — partially built in Phase 1a)**
- Verify provider id-tokens fully server-side: signature against Apple/Google
  JWKS (cached, refreshed), `iss`, `aud` = our client ids, `exp`. Never
  accept a client-asserted user id — the current `x-nativread-user-id` UUID
  header is MVP-only and is on the P1 kill list before the paid phase.
- Sessions: opaque random tokens (≥128-bit) or short-lived signed JWTs with
  rotation; store only hashes of opaque tokens server-side.

**Transport & platform**
- TLS only; HSTS. Security headers on every response:
  `X-Content-Type-Options: nosniff`, `Referrer-Policy:
  strict-origin-when-cross-origin`, restrictive `Permissions-Policy`.
- Non-root container; read-only filesystem except a size-capped job scratch
  dir.

**Input handling (every route)**
- Schema-validate every request body/param (zod at the boundary); reject
  unknown fields; hard body-size caps at platform level *and* in-route.
- EPUB = hostile zip (T5): size cap, entry-count cap, per-entry and total
  decompressed-size caps, path-traversal rejection, per-job sandbox dir, no
  symlink following. Same guards on the iOS download path (TODOS
  decompression-bomb guard).
- Multipart filename: server assigns `<uuid>.epub`; never interpolate client
  filenames into headers or paths.

**Authorization & isolation**
- Every data access keyed by authenticated `userId`; all lookups per-user
  scoped (T1 — done). The isolation regression test
  (`test/route-isolation.test.ts`) stays exhaustive as routes are added —
  isolation is a legal bright line, so it gets a test, not a convention.
- Entitlements granted only after server-side StoreKit 2 verification;
  dedupe on transaction id (T7).

**Abuse & cost containment (the free endpoint is the attack surface)**
- Per-user/day rate limit + word cap on free chapters; `(userId, sourceHash)`
  dedup; per-book `COST_CEILING_USD`; **global daily spend kill-switch** (T4).
- Login required even for free tier.
- Account-disable switch for credible rightsholder complaints (legal
  SHOULD-FIX) — also the answer to induced-infringement optics: visible
  attestation + takedown responsiveness, documented.

**Secrets & data at rest**
- AI provider key server-only, injected via the PaaS secret store, never in
  logs, denylisted in error-monitoring payloads (T19 scrub + its test).
- Ephemeral-by-design storage IS the data-security posture: source deleted on
  completion, result deleted on delivery (14d window / 30d cap), long-term
  state = metadata only. The best breach response is having nothing to breach.
- Postgres: least-privilege app role, parameterized queries only, encrypted
  backups, funnel + waitlist rows metadata-only and pruned (T18).

**Monitoring & response**
- Backend-only Sentry-class monitoring, scrubbed (T19); page on
  paid-but-undelivered and kill-switch trips (including safety-filter
  refusals surfacing as job failures).
- Structured logs without book content or tokens; retention ≤ 30d.
- One-page incident runbook: rotate key → trip kill-switch → disable route →
  restore. Written before launch.

**Pre-launch verification**
- Automated dependency + container scan (Trivy/`bun audit`) in CI.
- **Automated abuse suite (eng D8 — was a manual pass): `abuse.test.ts`**
  integration suite in quire-translator CI, extending the
  `route-isolation.test.ts` pattern: replay a purchase txn (dedupe rejects),
  upload a zip-bomb fixture (caps reject), hit another user's job id
  (isolation rejects), spam the free endpoint past the limit (rate limit +
  kill-switch trip), submit a moderation-trip fixture (refusal branch fires) —
  every probe must fail loudly, on every PR forever. Rate-limit/kill-switch
  cases use lowered test-mode thresholds. A human staging pass before Stage 2
  and Stage 3 remains as a sanity walk, but the suite is the net.

---

## Immediate next actions (this week)

1. **Counsel engagement** with the §3 agenda; ask for the week-1 preliminary
   read (longest lead time, and it soft-gates the website/SKUs/press).
2. **NativBook name clearance** (App Store + trademark knock-out + domain) —
   before any public asset exists.
3. **T25 backend half + robustness test** — OPF AI-marker in delivered EPUBs,
   survives re-export; small and deadline-bound.
4. **Start DE/ES validation runs** + arrange native-speaker reads.
5. Turn on the free GitHub protections (§7) — under an hour for both repos.

## Eng-review implementation tasks (2026-07-07)

Synthesized from the /plan-eng-review findings (D2–D13). E-numbers to avoid
clashing with translator-plan T-numbers. P1 blocks ship; P2 lands same branch.

Refusal + restore flow (the two new branches, for orientation):

```
upload ──► free chapter (T3) ──► provider ──► ok ──────────► deliver preview
   │                                │
   │                                └─ REFUSAL (deterministic)
   │                                     ├─ distinct non-retry copy
   │                                     ├─ credit NOT consumed
   │                                     └─ log → T15 datum + T18 bucket
   │
   └─► purchase (T7) ─ entitlement(userId, sourceHash, targetLanguage)
            │
   reinstall/re-upload same (hash, lang) ──► entitlement FOUND
            └────────────────────────────────► re-deliver / re-run, NO charge
```

- [ ] **E1 (P1, human: ~1d / CC: ~1-2h)** — backend — T25 marker: pin exact CoP-aligned OPF spec, inject marker + colophon
  - Surfaced by: Architecture #1 (D2) — plan said "OPF marker" with no vocabulary; EC Code of Practice final 2026-06-10
  - Files: quire-translator EPUB build step; spec recorded in blueprint §5
  - Verify: validation test asserts exact property+value + dc: entry + colophon + re-zip round-trip
- [ ] **E2 (P1, CRITICAL regression, human: ~0.5d / CC: ~1h)** — backend+ios — marked EPUB stays valid + importable
  - Surfaced by: Test review REGRESSION RULE — T25 modifies the working delivery build step
  - Verify: build → EPUB validity check → import in app; blocks ship if red
- [ ] **E3 (P1, human: ~0.5d / CC: ~30min)** — backend — T3 moderation-refusal branch
  - Surfaced by: Architecture #3 (D4) — refusal is deterministic; generic retry re-burns cost
  - Verify: fake-provider refusal test: distinct error code, credit not consumed, T15+T18 events emitted
- [ ] **E4 (P1, human: ~0.5d / CC: ~30min)** — backend — `targetLanguage` in entitlement/tier/job keys
  - Surfaced by: Codex #2 (D9) — multi-language launch collides on `(userId, sourceHash)`
  - Verify: isolation + entitlement tests extended to the widened key; free trial stays per-book
- [ ] **E5 (P1, human: ~1d / CC: ~1h)** — backend+ios — re-upload entitlement restore (T17a)
  - Surfaced by: Codex #7 (D11) — consumables have no Apple-side restore
  - Verify: re-upload test: no double-charge, no double-grant; purchase UI states the guarantee
- [ ] **E6 (P1, human: ~0.5d / CC: ~30min)** — backend — T18 failure-bucket events
  - Surfaced by: Codex #6 (D12) — kill signal needs a denominator control
  - Verify: each bucket emitted from its failure path; retention/pruning covers new rows
- [ ] **E7 (P1, human: ~0.5d / CC: ~30min)** — backend — waitlist `(userId, language)` write
  - Surfaced by: Test review — dedupe idempotent, rides T4 rate limit, per-user scoped, metadata-only
  - Verify: dedupe + rate-limit + isolation tests (extend route-isolation.test.ts)
- [ ] **E8 (P1, human: ~1d / CC: ~1h)** — ios — ReviewPromptPolicy + picker gating tests
  - Surfaced by: §4/§6 spec + Code Quality #6 (D7) — hardcoded passed-languages list
  - Verify: ReviewPromptPolicyTests (first-translated / third-book / fires-once / never-on-error) + picker shows passed list + "Other"→waitlist
- [ ] **E9 (P1, human: ~0.5d / CC: ~1h)** — both repos — CI + GitHub protections per §7
  - Surfaced by: §7 + Architecture #4 (D5) — nativread unit-only; translator install/typecheck/test/lint; SHA-pinned actions; `permissions: contents: read`; secret scanning + push protection + Dependabot
  - Verify: green runs on a test PR in each repo
- [ ] **E10 (P1, human: ~2d / CC: ~1-2h)** — backend — `abuse.test.ts` automated abuse suite
  - Surfaced by: Test review #7 (D8) — §8 manual pass automated; five probes, loud failures
  - Verify: suite red if any probe is accepted; runs in CI
- [ ] **E11 (P2, human: ~1h / CC: ~15min)** — website — static host + deploy-on-push + domain-at-clearance
  - Surfaced by: Architecture #2 (D3) — distribution gap on the Stage 3 critical path
  - Verify: placeholder page live on the cleared domain over TLS
- [x] **E12 (P1, done in this review)** — docs — translator-plan.md sync pass (D10): supersede notes, DeepSeek→Western wording, T13/T14→P1, key widening, T17 split, T18 buckets

**Worktree parallelization:** Lane A (backend: E1→E2, E3–E7, E10 — same repo,
shared `lib/`, sequential-ish) · Lane B (iOS: E8, E2's import half) · Lane C
(E9 CI + E11 website — independent). Launch A and B in parallel; C anytime.
Lanes A/B meet at E2's end-to-end verify.

## NOT in scope (decided 2026-07-07)

- Gift-a-translation mechanics — cross-account delivery breaks per-user
  isolation (legal bright line).
- Website email waitlist — a PII store before a compliance deadline; the
  in-app waitlist answers the launch question; revisit post-launch.
- Dual-track global reader launch — solo-builder spread pre-revenue.
- Beta-labeled unvalidated languages — a label doesn't protect the rating
  with this persona.
- Worldwide storefronts at launch — EU first, expand post-launch.
- "Translated book travels" as a growth channel — contradicts the legal
  posture; export is for the user's own devices only.
- (eng review 2026-07-07) Server-driven launch-language list — hardcoded
  in-app list suffices for deliberate language launches; upgrade path in TODOS.
- (eng review 2026-07-07) XCUITests in CI — wedge-flaky on shared runners at
  10× minute billing; they stay a local pre-release ritual.
- (eng review 2026-07-07) Exotic entitlement recovery (new Apple ID, lost
  file) — stays T17b/P3 support path; the P1 re-upload restore covers the
  common case.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | CLEAR | 10 proposals, 9 accepted, 1 deferred; landscape check falsified the moat claim → repositioned |
| Codex Review | `/codex` (outside voice) | Independent 2nd opinion | 2 | ISSUES_FOUND → absorbed | Run 1 (CEO): 25 findings, 4 founder-decided. Run 2 (eng): 10 findings — 4 substantive accepted (D9–D12: targetLanguage key, doc sync, restore→P1, funnel buckets), 4 informational watch items, 2 already-handled |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR | 7 issues (4 arch, 2 quality, 1 test) + 4 Codex findings absorbed; 13 test gaps + 1 CRITICAL regression test folded into E1–E11; 0 unresolved |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | required before website build (§3) |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CODEX (eng run):** found the multi-language schema collision (D9) and three doc/priority staleness classes (D10) the section review missed; informational watch items retained: child-buyer flow friction (#5), quality-proof page vs modern-genre mismatch (#8), timeline optimism (#9 — the plan's own "sequence is the contract" hedge stands), DE/ES quality surface vs Hungary-first marketing (#10).
- **CROSS-MODEL:** no tension — Codex findings were complementary to the Claude section findings (schema/data-model vs spec/testing gaps); both agree the isolation bright line and the paid-but-undelivered=0 posture are the load-bearing invariants.
- **VERDICT:** CEO + ENG CLEARED — ready to implement E1–E11 / remaining T-tasks. Design review still gates the website build; DX review optional.

NO UNRESOLVED DECISIONS
