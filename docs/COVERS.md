# Onboarding cover art

The welcome screen's drifting shelf (`Views/Onboarding/OnboardingArt.swift`)
shows real jackets of real editions, in the reader's own language. Every image
is public domain; none is a modern edition's cover.

Assets are named `Cover-<language>-<slug>` in `Assets.xcassets`, scaled to
400 px on the long edge (JPEG, quality 78) — the shelf draws them 76 pt wide.

To add or replace one: drop the file in the matching imageset, record its
source in the table below, and add the slug to the right row in
`OnboardingShelf`. Names are checked against the catalog by
`OnboardingShelfTests.testEveryCoverResolves`.

## English

Covers by [Standard Ebooks](https://standardebooks.org), released into the
public domain (CC0): a public-domain painting under the edition's own
typography.

| Slug | Book | Source |
| --- | --- | --- |
| `alice` | Alice's Adventures in Wonderland — Lewis Carroll | standardebooks.org/ebooks/lewis-carroll/alices-adventures-in-wonderland |
| `pride` | Pride and Prejudice — Jane Austen | standardebooks.org/ebooks/jane-austen/pride-and-prejudice |
| `mobydick` | Moby Dick — Herman Melville | standardebooks.org/ebooks/herman-melville/moby-dick |
| `frankenstein` | Frankenstein — Mary Shelley | standardebooks.org/ebooks/mary-shelley/frankenstein |
| `expectations` | Great Expectations — Charles Dickens | standardebooks.org/ebooks/charles-dickens/great-expectations |
| `dracula` | Dracula — Bram Stoker | standardebooks.org/ebooks/bram-stoker/dracula |
| `doriangray` | The Picture of Dorian Gray — Oscar Wilde | standardebooks.org/ebooks/oscar-wilde/the-picture-of-dorian-gray |
| `janeeyre` | Jane Eyre — Charlotte Brontë | standardebooks.org/ebooks/charlotte-bronte/jane-eyre |

## Hungarian

Scans of the original editions, from Wikimedia Commons, all tagged public
domain.

| Slug | Book | Commons file |
| --- | --- | --- |
| `egricsillagok` | Egri csillagok — Gárdonyi Géza (1901) | `File:Egricsillagok.jpg` |
| `palutcaifiuk` | A Pál utcai fiúk — Molnár Ferenc | `File:PaulStreetBoysBookCover.jpg` |
| `aranyember` | Az arany ember — Jókai Mór (1872) | `File:Az arany ember 1872.jpg` |
| `szentpeteresernyoje` | Szent Péter esernyője — Mikszáth Kálmán (1895) | `File:Szent Péter esernyője regény (Mikszáth Kálmán) első kiadása (1895).jpg` |
| `koszivuemberfiai` | A kőszívű ember fiai — Jókai Mór | `File:Jokai-mor-a-koszivu-ember-fiai-i-vi-8139191-nagy.jpg` |
| `toldiesteje` | Toldi estéje — Arany János (1854) | `File:Toldi estéje (1854).jpg` |
| `embertragediaja` | Az ember tragédiája — Madách Imre (1861) | `File:Az ember tragédiája (első kiadás) 1861.jpg` |
| `legyjomindhalalig` | Légy jó mindhalálig — Móricz Zsigmond (Athenaeum) | **unrecorded** — see below |

## German

Title pages and bindings of the original editions, from Wikimedia Commons,
all tagged public domain.

| Slug | Book | Commons file |
| --- | --- | --- |
| `prozess` | Der Process — Franz Kafka (1925) | `File:Kafka Der Prozess 1925.jpg` |
| `effibriest` | Effi Briest — Theodor Fontane (1896) | `File:Theodor Fontane - Effi Briest. Titelblatt der ersten Buchausgabe 1896.jpg` |
| `faust` | Faust — J. W. von Goethe | `File:Faust, Titelblatt der Erstausgabe.jpg` |
| `werther` | Die Leiden des jungen Werthers — J. W. von Goethe (1774) | `File:GoetheDieLeidenDesJungenWerthersTitelblatt1774S51.jpg` |
| `undine` | Undine — Friedrich de la Motte Fouqué | `File:UndineEineErzählungTitelblatt-0.png` |
| `zarathustra` | Also sprach Zarathustra — Friedrich Nietzsche | **unrecorded** — see below |
| `buddenbrooks` | Buddenbrooks — Thomas Mann | **unrecorded** — see below |
| `kinderhausmarchen` | Kinder- und Hausmärchen — Brüder Grimm | **unrecorded** — see below |

## Spanish

Six rather than eight: Commons has fewer usable Spanish first-edition jackets,
and both rows draw on the same six in different orders.

| Slug | Book | Commons file |
| --- | --- | --- |
| `quijote` | El ingenioso hidalgo Don Quixote de la Mancha — Cervantes (1605) | `File:Miguel de Cervantes (1605) El ingenioso hidalgo Don Quixote de la Mancha.png` |
| `regenta` | La Regenta — Leopoldo Alas "Clarín" (1884–85) | `File:Portada de La Regenta (1884-1885).jpg` |
| `niebla` | Niebla — Miguel de Unamuno (Renacimiento, 1914) | `File:1914, Niebla (nivola), editoral Renacimiento, Miguel de Unamuno.jpg` |
| `lazarillo` | La vida de Lazarillo de Tormes — anonymous (1554) | `File:Lazarillo de Tormes.png` |
| `sombrero` | El sombrero de tres picos — Pedro A. de Alarcón (1874) | `File:El sombrero de tres picos (Portada de 1874).jpg` |
| `madrenaturaleza` | La madre naturaleza — Emilia Pardo Bazán (1887) | `File:Emilia Pardo Bazán 1887 La madre naturaleza tomo I (cover).jpg` |

## Open: four unrecorded sources

Four images were fetched from Wikimedia Commons under a public-domain tag, but
the exact file name was lost before it was written down: `hu/legyjomindhalalig`,
`de/zarathustra`, `de/buddenbrooks`, `de/kinderhausmarchen`. All four are
scans of pre-1930 editions whose public-domain status is not in question, but
the attribution trail is incomplete.

Before the next release, either re-source those four from Commons and record
the file name here, or replace them. Everything else in this document was
confirmed by matching the shipped image byte-for-byte against the Commons
thumbnail it came from.
