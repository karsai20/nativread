# NativRead security audit — 2026-07-22

## Executive summary

The reviewed iOS and Cloudflare implementation has no known open Critical or
High-severity finding after the fixes in this review. This is a source-level
and local integration assessment, not a certification or a live penetration
test. During follow-up provisioning, Wrangler was authenticated, an EU D1
database was created and migrated, and the NativRead product site was deployed
to Cloudflare Pages at `https://nativread.com/`. The legal pages are linked only
from the footer and remain explicitly marked `noindex` while their operator
placeholders are unresolved. The production Worker remains disabled: paid
product activation, Docker, R2/Queues/Containers,
secrets, the backend URL, StoreKit verification, and final legal operator
details are still outstanding.

The Cloudflare design is appropriate for this workload. The small API and
authorization layer runs in Workers, metadata and credit invariants live in
D1, short-lived EPUB objects live in R2, Queue provides backpressure, Workflow
owns durable orchestration, and the memory-heavy EPUB/AI work runs in an
isolated Container. The existing Next/Bun service remains a development and
rollback path.

## Scope

- NativRead iOS application, including EPUB import, WKWebView reader,
  translation client, Apple session handling, account deletion, onboarding,
  Terms and Privacy surfaces.
- The new `cloudflare/` Worker, D1 schema, R2 object model, Queue consumer,
  Workflow, Container binding, Bun runner, Dockerfile, Wrangler configuration,
  Pages deployment workflow, and legal Pages content.
- Existing Next/Bun endpoints affected by raw EPUB upload, identity,
  entitlement, credit, retention, and dependency changes.
- Dependency and CI configuration visible in both local repositories.

Out of scope: Cloudflare account/IAM configuration, deployed DNS/TLS, live
Apple and Gemini credentials, App Store Server API behavior, Cloudflare's
internal platform, and a third-party legal opinion.

## Threat model and trust boundaries

```text
iOS app
  -> Worker API: authentication, authorization, request limits, rate limits
     -> EU D1: accounts, jobs, preview claims, credits, entitlements
     -> EU R2: short-lived source and result EPUBs
     -> Queue: job id only, serialized dispatcher/backpressure
        -> Workflow: durable state and paid-step replay boundary
           -> EU Container: untrusted EPUB parsing and Gemini calls
              -> Google Gemini API: disclosed external AI processor
```

The EPUB and every client-supplied identifier are treated as untrusted. The
Worker does not unzip EPUB files. The Container receives neither D1 nor R2
credentials, is addressed by a server-generated job UUID, authenticates
internal calls with a separate secret, and limits internet access to the
configured Gemini host.

## Findings closed during the review

### SEC-01 — Hostile EPUB extraction (High, fixed)

The iOS import path previously relied on ZIP extraction without app-level
limits, and OPF/manifest references could resolve outside the extracted book.
That allowed decompression exhaustion and cross-book/app-private file reads if
the ZIP layer or EPUB metadata was malicious.

Fixes:

- 128 MiB compressed archive cap, 512 MiB total expanded cap, 64 MiB per-entry
  cap, and 10,000-entry cap on device.
- Traversal, absolute paths, Windows-style traversal, canonical path aliases,
  duplicate paths, symlinks, and integer overflow are rejected before unzip.
- `container.xml`, OPF, spine, cover, NAV, and NCX references must remain under
  the current extracted-book root.
- Duplicate manifest IDs no longer trigger a dictionary precondition crash.
- The public backend separately enforces tighter 32 MiB / 128 MiB / 2,000-entry
  limits, and the Worker streams the archive to the isolated Container.

### SEC-02 — Active EPUB content and data exfiltration (High, fixed)

EPUB XHTML is attacker-controlled content displayed in a JavaScript-enabled
WKWebView. Script stripping alone was not a sufficient network boundary.

Fixes:

- Imported spine documents are sanitized fail-closed.
- An offline Content Security Policy blocks remote connections, scripts,
  frames, forms, plugins, and remote assets while allowing local/data images,
  fonts, media, and app styling.
- Reader navigation is restricted to `about:` and file URLs contained in the
  current extracted book. Chapter loads are checked against the same root.
- The existing native Apple Look Up selection action remains available.

### SEC-03 — Known dependency advisories (High/Moderate/Low, fixed)

The initial dependency audit reported advisories through Sharp,
`fast-xml-parser`, PostCSS, and DOMPurify. Direct versions and overrides were
updated. The final `bun audit` reports no known vulnerability. ZIPFoundation is
resolved to 0.9.20, newer than its historical symlink-traversal fix.

### SEC-04 — Landscape hardware overlap (Medium, fixed)

Edge-to-edge WKWebView layout could report a transient zero safe-area inset
while rotating, allowing text under the sensor housing. The reader now merges
window/container insets and applies a symmetric 64-point compact-height
fallback gutter. The landscape UI test waits for real landscape geometry
before measuring and verifies that pagination remains swipeable.

### SEC-05 — Translation retry and credit consistency (High/Medium, fixed)

Automatic replay of a paid provider call can cause duplicate external spend,
while non-atomic credit bookkeeping can overspend or lose refunds.

Controls:

- D1 constraints enforce non-negative balances and valid job states. During
  this review, a concurrent same-job reservation race was found and removed:
  reservation, refund, and finalization now move account totals through D1
  triggers in the same statement. Duplicate reservation inserts do not fire
  the movement twice, and an unaffordable insert rolls back completely.
- Credits are reserved before a full translation, finalized only after
  publication, and refunded on failure/cancellation.
- One free preview is allowed per account and source hash.
- Queue dispatch is serialized and workflows use a unique instance per retry.
- The provider-calling Workflow step has automatic retries disabled. Later
  publication/refund steps remain durable and idempotent.
- Production unsigned credit grants are disabled; the purchase endpoint fails
  closed until signed App Store transaction verification is implemented.

### SEC-06 — Cross-account access and deleted sessions (High, fixed)

Controls:

- Apple OIDC tokens are issuer, audience, signature, expiry, and subject
  validated before a server session is minted.
- The internal user identifier is a one-way SHA-256 value; raw Apple subjects,
  names, and email addresses are not stored.
- Production rejects the development `x-nativread-user-id` identity path.
- Every D1 job lookup and every R2 object key is user-scoped; object keys are
  derived server-side from validated UUIDs.
- Session verification also checks that the account still exists, immediately
  invalidating sessions after deletion.
- Account deletion first revokes Apple authorization, then cancels workflows,
  refunds reservations, deletes the user's R2 prefix, and removes D1 data.

### SEC-07 — Ambiguous legal assent and bundled AI permission (High, fixed in code)

The prior translation flow did not create sufficiently specific, versioned
evidence that a user actively accepted the terms applicable to a particular
book. It also risked presenting legal terms and optional AI processing as one
undifferentiated decision.

Controls:

- A new, non-preselected clickwrap appears contextually before a translation,
  rather than turning the product landing page into a legal warning page.
- The rights attestation names the selected book and requires a lawful basis to
  translate it; merely owning a copy is not represented as sufficient.
- Terms acceptance and the separate external-AI processing permission are two
  independent affirmative actions. Refusing AI processing prevents the upload.
- D1 records an immutable acceptance ID, pseudonymous account ID, source hash,
  terms and attestation versions, server timestamp, locale, and notice surface.
  It intentionally does not store the book title or book text.
- Both the app and Worker reject missing, stale, preselected, malformed, or
  client-backdated acceptance claims. A terms version change requires renewed
  assent, and the full archived terms remain reachable from the checkbox.
- Users can clear saved future AI-processing permissions in Settings without
  pretending that already completed processing can be retroactively undone.

This is implementation evidence, not a conclusion that the contract will be
enforceable in every jurisdiction. Final operator data and EU/Hungarian legal
review remain release gates.

### SEC-08 — Unbounded request work and AI cost amplification (High, fixed in code)

Controls:

- JSON request bodies are read as a stream and cancelled once they exceed 16
  KiB, including when `Content-Length` is absent or false.
- A translation may reserve at most USD 3 of estimated provider spend. Atomic
  D1 reservations fail closed at USD 5 per UTC day and USD 25 per UTC month
  across the service, and are released or finalized on every terminal path.
- Queue concurrency is one, active translations are capped per account, and
  Container maximum instances are bounded. The paid provider step has a
  30-minute timeout and no automatic retry.
- Workflow publication is replay-safe: a repeated durable step settles the
  existing published result instead of deleting it or spending again.
- Logs are structured and avoid user-controlled format strings, EPUB paths,
  chapter text, tokens, and provider bodies.

These application limits cap Gemini reservations, not the full Cloudflare bill.
Cloudflare billing alerts and account-level spend monitoring are still required.

## Additional controls reviewed

- Strict bearer-token grammar, 16 KiB streamed JSON bodies, bounded EPUB uploads,
  server-generated request/job IDs, fail-closed route matching, and no
  permissive CORS policy.
- Per-IP and per-account D1 rate limits plus global translation concurrency and
  Queue/Container instance caps.
- API responses use `no-store`, `nosniff`, no-referrer, same-origin resource
  policy, frame denial, and a default-deny CSP.
- R2 source/result objects are deleted after a consumed download; a scheduled
  cleanup handles abandoned jobs and a bucket lifecycle rule is the final
  backstop.
- Production secrets are Wrangler secrets, not variables or image layers.
  Session and Container internal tokens must be independent values of at least
  32 random bytes.
- GitHub Actions use immutable commit SHAs. The Container base image is pinned
  by digest. The Pages site also ships restrictive response headers.
- iOS ATS does not allow arbitrary loads. Plain HTTP is accepted only for the
  explicit local-network development flow; the production endpoint must be
  HTTPS.

## Verification evidence

| Check | Result |
|---|---|
| iOS unit tests | 225 passed, 0 failed |
| Reader journey UI suite | 17 passed, 0 failed on iPhone 17 Pro / iOS 26.2 |
| Backend and Cloudflare tests | 174 passed, 0 failed, 446 assertions |
| Root and Cloudflare TypeScript checks | Passed |
| iOS Release simulator build | Passed |
| Next.js production build | Passed |
| Wrangler Worker bundle dry-run | Passed with EU R2, D1, Queue, Workflow, and Container bindings |
| Local D1 migration | Applied successfully; schema-invariant tests passed |
| Remote EU D1 migrations | `0001`, `0002`, and `0003` applied; clickwrap records and atomic AI budgets verified by schema tests |
| Production product site | `https://nativread.com/`; HTTP 200 with default-deny CSP, HSTS, frame denial, `nosniff`, and no tracking scripts |
| Pages preview protection | Branch and deployment hostnames return `X-Robots-Tag: noindex, nofollow` |
| Production mobile Lighthouse | Performance 99, Accessibility 100, Best Practices 100, SEO 100; LCP 2.1 s, CLS 0, TBT 0 ms |
| Social preview metadata | Absolute canonical/Open Graph/Twitter metadata verified with a crawler user agent; the production 1200×630 PNG returns HTTP 200 and matches the built asset byte-for-byte |
| Container runner smoke test | `/ping` 200, unauthorized `/inspect` 401, authorized real-EPUB `/inspect` 200 |
| Semgrep, backend tracked files | 0 findings (118 rules, 73 files) |
| Semgrep, Cloudflare files including untracked | 0 findings (219 rules, 19 targets) |
| Semgrep, iOS auto + secrets | 0 findings (55 rules, 102 targets) |
| Bun dependency audit | No vulnerabilities found |
| Secret-pattern review | No production secret found; example PEM is an explicit placeholder |
| Whitespace/patch validation | `git diff --check` passed in both repositories |

The complete Container image was not built because no Docker daemon is
available. The runner itself was exercised directly with Bun and a real EPUB;
the Wrangler bundle was built with container rollout disabled.

## Open production gates

These are release blockers, not accepted production risks:

1. Accept Cloudflare billing and enable the paid Workers and R2 products, then create the EU R2 bucket and
   Queue/DLQ with the configured retention. Wrangler authentication, the EU D1
   database/migration, its production UUID, and the Pages deployment are done.
2. Build and scan the complete pinned Container image with Docker, then deploy
   it from CI or a controlled workstation.
3. Add narrowly scoped Cloudflare credentials and the independent Apple,
   session, Gemini, and Container secrets. Verify secret rotation and recovery.
4. Deploy, run live Apple login/account deletion, preview, full translation,
   result consumption, rate-limit, retention, and cross-account tests, then put
   the verified HTTPS Worker URL into the iOS production configuration.
5. Implement App Store Server API signed-transaction verification. Keep the
   current production purchase endpoint at HTTP 501 until it is covered by
   replay, refund, family/account, and cross-user tests.
6. Replace every `[[OPERATOR_NAME]]`, `[[OPERATOR_ADDRESS]]`, and
   `[[CONTACT_EMAIL]]` legal placeholder and obtain legal review before App
   Store submission.
7. Configure Cloudflare log/analytics access and retention. Do not log book
   content, tokens, authorization codes, private keys, or full provider bodies.
8. EU D1/R2 placement and EU Container constraints do not force TLS termination
   or Worker edge execution into the EU. If strict EU-only edge processing is a
   requirement, enable and validate Cloudflare Regional Services/Data
   Localization Suite. Disclose the separate Gemini processing geography.
9. Run a post-deployment external penetration test before enabling real
   payments. Include IDOR, session replay, race conditions, malformed ZIP/XML,
   oversized streaming bodies, Queue redelivery, Workflow cancellation, and
   account-deletion races.
10. Enable active Google Cloud billing so Gemini is a Paid Service for this EEA
    production use, review the applicable data-processing terms and data-sharing
    settings, and verify the provider's retention/geography behavior. Add
    Cloudflare billing notifications: the in-app USD 5/day and USD 25/month
    limits protect Gemini spend, not platform charges or abuse outside that path.

## Platform references

- [R2 data location and EU jurisdiction](https://developers.cloudflare.com/r2/reference/data-location/)
- [D1 data location](https://developers.cloudflare.com/d1/configuration/data-location/)
- [Containers placement constraints](https://developers.cloudflare.com/containers/platform-details/placement/)
- [Queues configuration](https://developers.cloudflare.com/queues/configuration/configure-queues/)
- [Workflows](https://developers.cloudflare.com/workflows/)
- [Cloudflare Data Localization Suite](https://developers.cloudflare.com/data-localization/)
- [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)
- [Containers pricing](https://developers.cloudflare.com/containers/pricing/)
- [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)
- [Gemini API terms](https://ai.google.dev/gemini-api/terms)

## Decision

The product-led website can remain on Cloudflare Pages while the placeholder
legal pages stay visibly marked as pre-release and excluded from indexing. Do
not submit the app with those placeholders, and do not enable paid whole-book
purchases as-is. Complete the production gates, then re-run this audit against
the deployed Worker, final legal text, and actual Cloudflare account
configuration before App Store submission.
