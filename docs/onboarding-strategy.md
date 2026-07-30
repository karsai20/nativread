# Onboarding strategy

Status: CURRENT PRODUCT DIRECTION, 2026-07-30.

## Product principle

NativRead has one core loop:

1. Bring a DRM-free book you already own.
2. Translate it into your language when needed.
3. Read the result in a calm, comfortable reader.

The app is not a vocabulary trainer or a language-learning product. Selected
text keeps the native iOS menu, including Apple's installed Look Up
dictionaries, but NativRead does not copy, save, export, or supplement those
definitions.

## First-run flow

First launch is three beats, each carrying **one sentence** and a live render
of the app's own UI:

1. *Add a book in a language you don't read.* — the shelf, with real covers
   and the library's own **Add a book** tile.
2. *We translate the first chapter free, so you can see what you'd get.* — the
   translator's detected language pair and its free-chapter card.
3. *You can close the app. We keep translating.* — the Translate tab's live
   job card, its bar creeping forward. The payoff closes the flow here: *The
   finished translation lands on your shelf, beside the original.*
4. Arrive at the empty shelf with one clear **Add a book** action.

Each sentence has to earn its screen. Say what is free and what is not: "the
first chapter is free" invites the reader to think we sell books, when what
they buy is a translation. Say why they would close the app before telling
them they can. Name the product by the second beat, or the walkthrough is
indistinguishable from any other reading app's.

This is not a feature carousel and not an illustration of the product. The
scenes are composed from the same components the real screens use
(`GeneratedCover`, `AppProgressTrack`, `AppPill`, the translator's card
treatment), so they cannot drift from the app or miss a translation. Every
beat states one necessary part of import → translate → read. There are no
intent quizzes, proficiency questions, dictionary setup, account creation, or
payment. Account and rights confirmation belong in the translation flow, at
the moment the reader asks for translation.

The payoff sits at the end rather than on a welcome screen: the closing moment
is what a reader remembers, and by then the words mean something. It states
where the translated book turns up and that the original survives, which is
the one thing nothing else in the flow says.

The target audience includes older readers, so onboarding follows these rules:

- no automatic advancement; every screen waits for an explicit action;
- never put language choice behind copy the user may not understand;
- 58-point primary controls and at least 48-point back controls;
- exactly one sentence per beat — no eyebrow, caption, or footnote layer;
- the sentence steps up to 38pt at accessibility text sizes, and the scene
  gives up its room so nothing is ever clipped;
- explicit step count and visible Back/Next labels;
- slow illustrative motion with a complete Reduce Motion fallback;
- portrait and landscape layouts without hidden or clipped actions.

## Empty shelf

The empty state owns the call to action. Do not also show the persistent
Translate/Import bar there:

- explain that EPUB, PDF, TXT, and supported DRM-free Kindle files can be added;
- use one prominent **Add a book** button;
- surface the DRM-free requirement without directing users to acquisition
  sources.

After the first book is present, the library may show Translate and Import as
persistent actions.

## Translation discovery

Translation is the differentiator and should be visible in the populated
library. The first free chapter is the product demonstration. The flow should:

- select a source book;
- detect and display its source language;
- show only target languages that passed the quality gate;
- ask for usage-rights confirmation;
- ask for Sign in with Apple only when translation is requested;
- let the reader leave while the backend continues;
- reconnect to the durable backend job after relaunch and import the result
  automatically.

## Reading help

Long-press selection uses the standard iOS text menu. Apple's **Look Up** is the
only dictionary surface. NativRead keeps its own **Highlight** action because
highlights are part of the reading workflow.

There is no saved-word list, vocabulary export, inline gloss mode, downloadable
dictionary pack, or custom definition sheet in the product direction.

## Success signal

The first-run funnel is deliberately small:

- onboarding completed → first book imported;
- eligible import → free chapter started;
- free chapter read → whole-book translation purchased;
- paid translation → translated book delivered and opened.

Every paid-but-undelivered result is a critical failure. Reading streaks and
habit metrics are not product goals.
