# NativBook Privacy Policy

**DRAFT — pending legal review. Not yet published.**
Effective date: [[EFFECTIVE_DATE]] · Version 0.1

NativBook is an ebook reader with an optional AI translation service. This
policy explains what data we handle, why, for how long, and what your rights
are. The short version: **the reader works entirely on your device; the
translation service touches your book only for as long as the translation
takes; we keep metadata, never your books.**

## 1. Who we are

Data controller: **[[OPERATOR_NAME]]**, [[OPERATOR_ADDRESS]].
Contact: [[CONTACT_EMAIL]].

## 2. What the app does NOT collect

- The reader itself (importing, reading, highlights, dictionary, settings)
  works **offline**. Books you import never leave your device unless you
  start a translation.
- We use **no analytics or advertising SDKs**. No third-party tracker runs in
  the app.
- We never sell or share personal data for advertising.

## 3. What we process when you use the translation service

| Data | Purpose | Retention |
|---|---|---|
| Sign-in identity (Apple or Google ID token → an internal user ID) | account, purchase entitlements, abuse prevention | until account deletion |
| The book file you upload | translating it | **deleted when the translation completes** |
| The translated book | delivering it to your device | **deleted on delivery** (kept max 14 days if your device is unreachable, hard cap 30 days) |
| Purchase records (Apple transaction ID, book hash, target language, price tier) | granting and restoring what you paid for | until account deletion |
| Service events (e.g. "translation started/failed", error category, language waitlist choice) | keeping the service working, fixing failures | pruned on a rolling window; metadata only, never book text |

"Book hash" means a fingerprint of the file — it lets us recognize the same
book (e.g. to restore a purchase) without storing the book itself.

## 4. Who processes data on our behalf (sub-processors)

- **Apple** — sign-in and in-app purchases (their own privacy terms apply).
- **[[AI_PROVIDER]]** — performs the machine translation. Your book's text is
  sent to them for processing under a data processing agreement; **it is not
  used to train their models** and is processed in EU/US regions
  ([[AI_PROVIDER_DPA_URL]]).
- **[[HOSTING_PROVIDER]]** — runs our server (region: EU).
- **[[ERROR_MONITOR]]** — backend error monitoring. Error reports are scrubbed:
  they never contain book text or your identity beyond a hashed user ID.

We have data processing agreements with each. If any of this list changes, we
update this policy before the change takes effect.

## 5. International transfers

Where processing happens outside the EEA (e.g. US regions of
[[AI_PROVIDER]]), it is covered by the EU–US Data Privacy Framework and/or
standard contractual clauses.

## 6. Legal bases (GDPR)

- Performing our contract with you (Art. 6(1)(b)): accounts, translation,
  purchases, delivery.
- Legitimate interest (Art. 6(1)(f)): abuse prevention, rate limiting,
  service reliability monitoring.
- Legal obligation (Art. 6(1)(c)): tax/accounting records of purchases.

## 7. Your rights

In the app: **Settings → Account** lets you **export your data** and **delete
your account** — deletion removes your account, entitlements metadata, and any
stored files immediately. You also have the GDPR rights of access,
rectification, erasure, restriction, portability, and objection — write to
[[CONTACT_EMAIL]]. You can complain to your supervisory authority; in Hungary
that is the NAIH (naih.hu).

## 8. AI transparency (EU AI Act)

Translations are produced by an AI system. Translated books are visibly
labeled in the app and carry a machine-readable marker inside the file, as
required by Article 50 of the EU AI Act.

## 9. Children

NativBook is not directed at children under 16 and we do not knowingly
process their data.

## 10. Changes

We will post any changes at [[POLICY_URL]] with a new effective date, and for
material changes we will tell you in the app.
