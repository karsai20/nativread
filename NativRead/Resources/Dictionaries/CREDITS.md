# Bundled Dictionaries — Credits

## WordNet

- **Source:** WordNet 3.1, Princeton University
- **Format:** StarDict (`.ifo` / `.idx` / `.dict.dz`)
- **License:** WordNet License (permissive)

WordNet is a lexical database of English maintained by the Cognitive Science
Laboratory at Princeton University. It is distributed under a permissive
license that allows free use, including in commercial products, provided the
copyright notice and license are retained.

> WordNet 3.0 Copyright 2006 by Princeton University. All rights reserved.
>
> THIS SOFTWARE AND DATABASE IS PROVIDED "AS IS" AND PRINCETON UNIVERSITY
> MAKES NO REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED.

Full license: https://wordnet.princeton.edu/license-and-commercial-use

More information: https://wordnet.princeton.edu/

## English–Spanish (gap — not yet bundled)

- **Status:** `BundledDictionary.enes` is wired in `DictionaryProvider`; the
  resource folder `enes/` is not yet present. When the Spanish language is
  chosen the provider silently falls back to WordNet only.
- **Next step:** Obtain an OFL- or CC-licensed EN→ES StarDict dictionary (e.g.
  from FreeDict <https://freedict.org/> or a Wiktionary extraction comparable
  to the EN→HU pipeline). Place the `enes.ifo`, `enes.idx`, and `enes.dict.dz`
  under `NativRead/Resources/Dictionaries/enes/` and add it to the Xcode target.

## English–German (gap — not yet bundled)

- **Status:** `BundledDictionary.ende` is wired in `DictionaryProvider`; the
  resource folder `ende/` is not yet present. When German is chosen the
  provider silently falls back to WordNet only.
- **Next step:** Same as EN→ES above — FreeDict has a `deu-eng` / `eng-deu`
  pair under GPL/FDL. Check license compatibility and adapt the build script.

## English–Hungarian (Wiktionary)

- **Source:** English Wiktionary translation data, extracted via **DBnary** (GETALP, Université Grenoble Alpes)
- **Format:** StarDict (`.ifo` / `.idx` / `.dict.dz`), built by `scripts/build_enhu_dict.py`
- **License:** **CC-BY-SA** (Creative Commons Attribution-ShareAlike) + GFDL — the same license as Wiktionary content

The English→Hungarian dictionary is derived from Wiktionary translation tables.
Wiktionary content is dual-licensed under CC-BY-SA and the GNU Free Documentation
License. DBnary extracts this content as RDF; see https://kaiko.getalp.org/about-dbnary/.

> Wiktionary data © Wiktionary contributors, licensed under CC-BY-SA.
> DBnary: Gilles Sérasset, "DBnary: Wiktionary as a Lemon-Based Multilingual
> Lexical Resource in RDF." Semantic Web Journal.

More information: https://www.wiktionary.org/ · https://kaiko.getalp.org/about-dbnary/
