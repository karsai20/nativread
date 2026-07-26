# Legal document pack — status & placeholders

Created 2026-07-07 by agent drafting. **Every file here is a DRAFT, not legal
advice.** The blueprint Stage 1 gate ("counsel sign-off before commercial
launch") remains open — the founder currently proceeds without counsel
(decision 2026-07-07); when counsel is engaged, these drafts are the review
input. Research basis: `../legal-posture.md` (authoritative posture) +
`../legal-research-2026-07-07.md` (case-law map).

## Files

| File | Purpose | Gate it satisfies |
|---|---|---|
| `privacy-policy.en.md` / `.hu.md` | GDPR privacy policy (App Store URL) | legal #4/#7, T16 |
| `terms-of-service.en.md` / `.hu.md` | ToS incl. ownership, personal use, refunds | legal #1/#7, T16 |
| `in-app-legal-copy.md` | Attestation, AI disclosure, colophon, refusal/restore copy (HU+EN) | T23, T16, T25, eng D4/D11 |
| `takedown-policy.en.md` | Rightsholder complaint handling | legal SHOULD-FIX, §8 abuse posture |

## Placeholders to fill before App Store submission (grep for `[[`)

- `[[OPERATOR_NAME]]` — the legal operator (sole developer name or company if
  one is formed before launch)
- `[[OPERATOR_ADDRESS]]`, `[[CONTACT_EMAIL]]`, `[[SUPPORT_EMAIL]]`
- `[[HOSTING_PROVIDER]]` + region — fixed by backend deploy choice
- `[[ERROR_MONITOR]]` — fixed by T19 (Sentry-class, backend-only)
- `[[TERMS_URL]]` — the hosted Terms URL, if a separate web copy is published
- `[[EFFECTIVE_DATE]]`

The AI provider is now fixed as the paid Google Gemini API and the privacy
policy URL is `https://nativread.com/privacy/`. The Cloudflare
Pages workflow and web document live in
`.github/workflows/cloudflare-pages.yml` and
`docs/public/privacy/index.html`. The `nativread-legal` Pages project and its
least-privilege GitHub secrets must exist before App Store submission.

## Rules for editing

- The HU and EN versions must stay in sync — edit both or neither.
- Facts in these docs mirror the architecture (ephemeral storage, metadata-only
  retention, per-user isolation, no analytics SDK). If the architecture
  changes, these docs are part of the change (same rule as ASCII diagrams).
- Voice: plain, calm, honest — the 50+ persona reads these. No legalese where
  a plain sentence works.
