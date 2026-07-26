# Legal research annex — AI book translation, private adaptation, competitor enforcement reality

Date: 2026-07-07. Status: **agent research, NOT legal advice** — input for the
counsel engagement (blueprint §3 agenda). `legal-posture.md` stays authoritative
on posture; this annex adds the case-law map and the "why do competitors still
exist" analysis the founder asked for.

## 1. The question underneath everything

Translation is an **adaptation** (derivative work), not a mere copy. That one
fact drives the whole legal picture:

- **Hungary (Szjt. 29. §):** translation is *átdolgozás* — an exclusive right
  of the author. The private-copying free use (Szjt. 35. §) is an exception to
  the **reproduction** right; no Hungarian statutory exception explicitly
  extends to adaptation. Whether a **purely private, never-published
  adaptation** (user translates their own book, shows it to nobody) needs
  authorization at all is doctrinally underdetermined — the standard
  commentaries (e.g. the IJOTEN entry on economic rights) simply don't
  distinguish private vs. public adaptation. **This is the precise week-1
  counsel question, and it is genuinely open, not settled-bad.**
- **EU level:** the InfoSoc Directive harmonizes reproduction/communication
  rights and their exceptions (private copy = Art 5(2)(b), reproduction only).
  The **adaptation right is NOT EU-harmonized** (only for computer programs) —
  so the private-translation question is answered by **national law, per
  member state**. Consequence for a DE/ES launch: the answer can differ in
  Germany and Spain. → added to the counsel agenda.

## 2. The case-law map for "operator stores the copy"

The accepted-risk fact pattern (server temporarily holds the user's book and
the translation) sits between two CJEU poles:

```
VCAST (C-265/16)                      NativRead                 Austro-Mechana (C-433/20)
service SOURCED the content ◄──── user supplies their own ────► purely passive cloud
+ actively made the copies          lawful copy; service            storage of user's
= private-copy exception            actively TRANSFORMS it          own uploads
  NOT available                                                  = private-copy exception
                                                                   available
```

- *VCAST*: a commercial cloud-recording service could not rely on the private
  copying exception because it **actively involved itself** in making the
  copies — and crucially it also *provided access to* the broadcast content
  itself.
- *Austro-Mechana*: private copying **does** extend to cloud storage where the
  provider is passive.
- NativRead is neither: the user brings their own lawfully acquired file
  (unlike VCAST), but the service actively processes it (unlike passive
  storage). No CJEU case is on all fours. Counsel's read should say which pole
  the "active transformation of user-supplied content, ephemeral, never
  distributed" pattern gravitates toward — and whether the analysis even runs
  through the private-copy exception at all, given translation is an
  adaptation (see §1: possibly a purely national-law question).

Note also: since the reproduction steps on our server are incidental to a
user-directed act on the user's own copy, counsel may consider the
temporary-reproduction exception (InfoSoc Art 5(1)) for the transient server
copies, separate from the adaptation question.

## 3. Why competitors exist un-sued — and what that does and doesn't prove

Research found **no lawsuit, fine, or takedown reported against any AI book
translation service** (BookTranslator.ai, BookTranslator.app, BookTranslate.ai,
Immersive Translate, eBook-translator apps). Why that is plausible:

1. **Invisibility of the act.** Private, non-published translations produce no
   public artifact a rightsholder could ever see. Enforcement requires a
   visible infringement; there is none.
2. **Damages economics.** A civil case needs an identifiable defendant, a
   provable act, and damages. A user privately translating a book they bought
   generates ~zero provable damages (arguably negative — they bought the book).
3. **Publisher attention is elsewhere.** The industry's AI litigation energy
   goes to *training-data* suits (Anthropic, Meta, etc.) and piracy sites —
   places with deep pockets or mass distribution.
4. **Liability shifted to the user.** The services universally use ownership
   attestations, framing themselves as user-directed tools (the same posture
   NativRead takes, with a stronger version: ephemeral server + no sharing).
5. **Jurisdictional distance.** Several are US-based (fair-use colored) or
   China-based browser extensions — hard or unattractive targets in the EU.

**What this does NOT prove:** legality. It's survivorship evidence. "Nobody has
been sued yet" is compatible with both "this is fine" and "nobody big enough to
sue has done it visibly enough yet." An EU-resident solo developer with a
named, App Store-visible product has a *different* exposure profile than an
anonymous browser extension.

**What it DOES prove:** present-day enforcement probability is low, and the
realistic risk ladder is:

| # | Risk | Likelihood | First contact | Our answer |
|---|------|-----------|---------------|------------|
| 1 | App Review 5.2 rejection | highest | review notes | attestation UI, "own books" framing, no acquisition features |
| 2 | Rightsholder C&D letter | low | email, not court | takedown/account-disable switch (§8), documented responsiveness |
| 3 | Actual civil suit | very low | after ignored C&D | ephemeral + user-owned copy + no distribution + attestation record |
| 4 | Criminal exposure | ~nil | — | criminal copyright needs commercial-scale *distribution*; the model is the opposite |

The posture (attestation, deliver-then-delete, per-user isolation, no sharing
loop) is exactly the "be on the right side when the wind turns" design — the
competitors mostly have weaker versions of it.

## 4. What changes in the plan from this research

1. **Counsel agenda gains one item:** HU/DE/ES national variance of the
   private-adaptation question (adaptation right is not EU-harmonized) —
   folded into blueprint §3.
2. **Counsel brief should lead with §1's framing** (adaptation vs.
   reproduction; VCAST/Austro-Mechana gap) so the week-1 read answers the
   right question instead of re-deriving it.
3. No change to the accepted-risk posture: research confirms it is the
   defensible middle, and confirms the week-1 preliminary read is worth its
   cost before public assets exist.

## Sources

- CJEU VCAST C-265/16 and Austro-Mechana C-433/20 analyses: IPKat
  (ipkitten.blogspot.com 2017/2022), Dechert OnPoint 2022, JIPLP 13(9).
- Szjt. 29. § / 35. §: net.jogtar.hu (1999. évi LXXVI. tv.), IJOTEN "Szerzői
  vagyoni jogok", Jogászvilág "Átdolgozás, feldolgozás, fordítás", SZTNH
  "Szerzői jog mindenkinek" (2023).
- InfoSoc exceptions overview: eur-lex LEGISSUM l26053; Wikipedia
  "Copyright and Information Society Directive 2001".
- Competitor scan: booktranslator.ai, booktranslator.app, booktranslate.ai,
  immersivetranslate.com, Jane Friedman "AI and Publishing FAQ" — no
  enforcement actions found as of 2026-07-07.
