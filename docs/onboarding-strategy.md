# Onboarding strategy

Status: CURRENT PRODUCT DIRECTION, 2026-07-20.

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

First launch is a short, user-paced explanation of the one core loop:

1. A language-aware animated welcome starts in the iPhone's language, keeps
   **Magyar / English** visible for confirmation, and presents the promise:
   **Your books. In your language.**
2. See how to add an owned book from Files.
3. See that translation continues safely after leaving the app and returns the
   finished book to the shelf.
4. See the comfort controls, page gestures, and Apple's native Look Up.
5. Arrive at the empty shelf with one clear **Add a book** action.

This is not a generic feature carousel. Every lesson explains one necessary
part of import → translate → read. There are no intent quizzes, proficiency
questions, dictionary setup, account creation, or payment. Account and rights
confirmation belong in the translation flow, at the moment the reader asks for
translation.

The target audience includes older readers, so onboarding follows these rules:

- no automatic advancement; every screen waits for an explicit action;
- never put language choice behind copy the user may not understand;
- 58-point primary controls and at least 48-point back controls;
- large Dynamic Type-aware copy, short paragraphs, and scroll fallback;
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
