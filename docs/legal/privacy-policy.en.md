# NativRead Privacy Policy

**DRAFT — pending legal review.**
Effective July 22, 2026 · Version 1.2

Reading is private by default. Your books stay on your device unless you
deliberately start an AI translation. This policy explains what data we
process, why, for how long, and what choices you have.

## 1. Who is responsible

Data controller: **[[OPERATOR_NAME]]**, [[OPERATOR_ADDRESS]].
Contact: [[CONTACT_EMAIL]]. Current support information is also available on
NativRead's App Store product page.

## 2. Private, offline reading

- Importing, reading, highlights, Apple Look Up, and reader settings work
  locally.
- NativRead contains no advertising or analytics SDK and does not sell
  personal data.
- A book leaves your device only when you choose AI translation.

## 3. Data used for translation

| Data | Purpose | Retention |
|---|---|---|
| Stable Sign in with Apple account identifier | account authentication, entitlements, abuse prevention | until account deletion |
| Uploaded EPUB and chosen target language | creating the translation | deleted on successful delivery; no longer than 30 days if processing is interrupted |
| Translated book | delivery to your device | deleted on delivery; no longer than 30 days if delivery is interrupted |
| Technical book fingerprint, translation status, purchase and entitlement data | access restoration, delivery, abuse prevention, service operation | until account deletion or for as long as law requires |
| Pseudonymous account, book fingerprint, acceptance ID, client and server time, locale, method, statement and Terms versions, and archived Terms URL | demonstrating active Terms acceptance | until account deletion, or as necessary for a legal claim |

NativRead does not request your name or email address from Apple. A technical
book fingerprint lets the service recognize the same file without retaining
the book itself.

## 4. AI and service providers

After your separate permission, the book text is sent to the **Google Gemini
API**, a third-party AI service, to create the translation. Its paid API does
not use prompts or responses to improve Google products or models. Google may
retain them for a limited period for abuse detection and required legal
disclosures. See the [Google Gemini API
terms](https://ai.google.dev/gemini-api/terms).

Apple processes sign-in and in-app purchase data under its own terms.
NativRead uses **Cloudflare** for hosting and compute. Book-file storage in
R2, the D1 metadata database, and translation containers are restricted to
the EU jurisdiction; the encrypted request may pass through Cloudflare's
global edge network. Cloudflare and the AI provider may process data only to
provide the service and must protect it to at least the level described here.

## 5. Legal bases

- Performance of a contract: account, translation, purchase, and delivery.
- Consent: sending book text to a third-party AI provider. You can decline and
  continue using the offline reader.
- Legitimate interests: abuse prevention and reliable service operation.
- Legal obligation: required tax and accounting records.

## 6. Retention and account deletion

The source and translated server copies are removed after successful delivery.
Normal automatic expiry is 24 hours; a separate storage safety rule ensures
that an object surviving an abnormal interruption is never retained beyond 30
days.

You can delete your translation account at **Settings → Account → Delete
Account**. After you reconfirm your Apple account, NativRead revokes Sign in
with Apple and permanently removes the backend account, translation jobs,
entitlements, and associated data it is not legally required to retain. Books
already stored in your local library are not removed. Deletion ends your
ability to restore past purchases.

## 7. Your rights

You can decline AI processing and continue using the offline reader. You can
withdraw saved permission for future AI processing at **Settings → Privacy
Controls → Forget AI Permissions**. This does not undo processing already
started or completed at your request; the app asks again before a future
translation.

Depending on applicable law, you may request access, correction, deletion,
restriction, or portability, and may object to processing by writing to
[[CONTACT_EMAIL]]. You may complain to your local supervisory authority; in
Hungary this is the NAIH.

## 8. Security and age

Sessions are stored in the iOS Keychain and translation requests use
authenticated connections. The translation service is for adults and does
not knowingly create accounts for people under 18.

## 9. Changes

Material changes to AI processing require new permission in the app. The
effective date and version are updated whenever this policy materially
changes. The published version is available at
https://nativread.com/privacy/.
