import Foundation
import NaturalLanguage

/// Reduces an inflected English word to candidate dictionary head-forms, so a
/// StarDict lookup of "moved", "running", or "wolves" can fall back to the
/// lemma the dictionary actually stores ("move", "run", "wolf").
///
/// WordNet and the EN→HU dictionary index base forms only, so an exact lookup
/// of an inflected selection returns nothing. Callers try `candidates(for:)`
/// in order and take the first that hits.
///
/// Apple's on-device lemmatizer (`NLTagger`) goes first — it handles irregulars
/// (`ran`→`run`, `mice`→`mouse`, `better`→`good`). Compact suffix rules back it
/// up for the regular cases `NLTagger` sometimes returns unchanged.
enum Lemmatizer {

    /// Punctuation/whitespace a text selection commonly drags in ("moved,").
    private static let trimSet = CharacterSet.punctuationCharacters
        .union(.whitespacesAndNewlines)

    /// Base-form candidates for `word`, in priority order, lowercased and
    /// deduped, excluding the original form (callers already tried it exactly).
    static func candidates(for word: String) -> [String] {
        let base = word.lowercased().trimmingCharacters(in: trimSet)
        guard base.count > 2 else { return [] }

        var seen: Set<String> = [base]
        var out: [String] = []
        func add(_ candidate: String) {
            guard candidate.count > 1, seen.insert(candidate).inserted else { return }
            out.append(candidate)
        }

        if let lemma = nlLemma(base) { add(lemma) }
        for candidate in suffixCandidates(base) { add(candidate) }
        // British → American spelling. The bundled dictionaries index the
        // American forms ("harbor", "color", "realize"), so a British-spelled
        // selection ("harbour", "colour", "realise") otherwise misses and
        // falls back to an English-only WordNet gloss. Americanize the base
        // and every candidate found so far, so "harbours" → "harbor" too.
        for form in [base] + out {
            if let americanized = americanize(form) { add(americanized) }
        }
        return out
    }

    /// Rewrites a British spelling to its American form, or nil when no rule
    /// applies. Conservative: the length guard keeps short words ("hour",
    /// "four", "rise") untouched, and these candidates are only tried after
    /// the exact form misses, so a stray rewrite can't shadow a real word.
    static func americanize(_ word: String) -> String? {
        // Longest suffixes first so "-isation" wins over "-ise".
        let rules: [(British: String, American: String)] = [
            ("isations", "izations"), ("isation", "ization"),
            ("ising", "izing"), ("ised", "ized"), ("ises", "izes"),
            ("ysing", "yzing"), ("ysed", "yzed"), ("yse", "yze"),
            ("ise", "ize"),
            ("ogues", "ogs"), ("ogue", "og"),
            ("ours", "ors"), ("our", "or"),
            ("res", "ers"), ("re", "er"),
        ]
        for rule in rules where word.hasSuffix(rule.British) {
            // Keep at least two leading letters so "re"/"ise"/"our" as whole
            // words (or tiny ones like "ogre") are never rewritten.
            guard word.count > rule.British.count + 1 else { continue }
            return String(word.dropLast(rule.British.count)) + rule.American
        }
        return nil
    }

    /// Apple's on-device lemma for a single word, or nil when it adds nothing.
    private static func nlLemma(_ word: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word
        let (tag, _) = tagger.tag(
            at: word.startIndex, unit: .word, scheme: .lemma
        )
        guard let lemma = tag?.rawValue.lowercased(),
              !lemma.isEmpty, lemma != word else { return nil }
        return lemma
    }

    /// Reverses regular English inflection: plural, 3rd-person, past, gerund.
    /// Returns several spellings per suffix (e.g. `moved` → `mov`, `move`)
    /// because the dropped letter isn't recoverable without the dictionary.
    private static func suffixCandidates(_ word: String) -> [String] {
        var out: [String] = []
        func emit(_ stem: String) { if stem.count > 1 { out.append(stem) } }

        if word.hasSuffix("ies") || word.hasSuffix("ied") {  // carries/carried → carry
            emit(String(word.dropLast(3)) + "y")
        }
        if word.hasSuffix("es") {                            // boxes → box, wishes → wish
            emit(String(word.dropLast(2)))
        }
        if word.hasSuffix("s"), !word.hasSuffix("ss") {      // books → book
            emit(String(word.dropLast()))
        }
        if word.hasSuffix("ed") {                            // walked → walk, moved → move
            let stem = String(word.dropLast(2))
            emit(stem)
            emit(stem + "e")
            if let undoubled = undouble(stem) { emit(undoubled) }  // stopped → stop
        }
        if word.hasSuffix("ing") {                           // walking → walk, moving → move
            let stem = String(word.dropLast(3))
            emit(stem)
            emit(stem + "e")
            if let undoubled = undouble(stem) { emit(undoubled) }  // running → run
        }
        return out
    }

    /// Collapses a doubled final consonant ("stopp" → "stop", "runn" → "run").
    private static func undouble(_ stem: String) -> String? {
        let chars = Array(stem)
        guard chars.count >= 3,
              let last = chars.last,
              chars[chars.count - 1] == chars[chars.count - 2],
              !"aeiou".contains(last) else { return nil }
        return String(stem.dropLast())
    }
}
