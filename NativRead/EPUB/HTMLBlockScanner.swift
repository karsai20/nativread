import Foundation

/// Finds the leaf prose blocks of an XHTML document and returns their raw
/// (still entity-encoded) text, in document order.
///
/// This is a deliberate port of the translation backend's block collection:
/// `node-html-parser`'s `parse()` followed by the chunker's `collectBlocks`.
/// The price a reader is charged is derived from these blocks, so "the same
/// blocks" has to mean the same on both sides — including the parser's own
/// quirks: `<br>` reads as a newline, `<script>`/`<style>`/`<pre>` bodies are
/// raw text and DO count, comments do not, and `<![CDATA[…]]>` is plain text.
enum HTMLBlockScanner {

    /// The elements the translator treats as one translation unit.
    static let blockTags: Set<String> = [
        "p", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote",
        "figcaption", "dd", "dt", "td", "th", "caption",
    ]

    /// Raw text of every leaf block element inside `<body>` (or of the whole
    /// document when it has no body), in document order.
    static func leafBlockRawTexts(inXHTML xhtml: String) -> [String] {
        let root = parse(xhtml)
        let scope = firstBody(in: root) ?? root
        var blocks: [Node] = []
        collect(from: scope, into: &blocks)
        return blocks.map(rawText)
    }

    // MARK: - Block collection

    private static func collect(from node: Node, into blocks: inout [Node]) {
        if let tag = node.tag, blockTags.contains(tag.lowercased()),
           !containsBlockDescendant(node) {
            blocks.append(node)
            return
        }
        for child in node.children where child.isElement {
            collect(from: child, into: &blocks)
        }
    }

    private static func containsBlockDescendant(_ node: Node) -> Bool {
        node.children.contains { child in
            guard let tag = child.tag else { return false }
            return blockTags.contains(tag.lowercased()) || containsBlockDescendant(child)
        }
    }

    /// Document-order equivalent of `querySelector("body")`.
    private static func firstBody(in node: Node) -> Node? {
        for child in node.children where child.isElement {
            if child.tag?.lowercased() == "body" { return child }
            if let found = firstBody(in: child) { return found }
        }
        return nil
    }

    /// `HTMLElement.rawText`: children concatenated, with `<br>` reading as a
    /// newline (node-html-parser issue #249).
    private static func rawText(_ node: Node) -> String {
        switch node.kind {
        case .text(let text):
            return text
        case .element(let tag) where tag.lowercased() == "br":
            return "\n"
        default:
            return node.children.map(rawText).joined()
        }
    }

    // MARK: - Document tree

    /// A parse node. Reference semantics because the port mirrors
    /// node-html-parser's mutable stack-and-reparent algorithm.
    private final class Node {
        enum Kind {
            case root
            case element(String)
            case text(String)
        }

        let kind: Kind
        private(set) var children: [Node] = []
        weak var parent: Node?

        init(_ kind: Kind) { self.kind = kind }

        /// Tag name exactly as written in the source; nil for text and root.
        var tag: String? {
            if case .element(let tag) = kind { return tag }
            return nil
        }

        var isElement: Bool { tag != nil }

        func appendChild(_ child: Node) {
            child.parent?.removeChild(child)
            child.parent = self
            children.append(child)
        }

        func removeChild(_ child: Node) {
            children.removeAll { $0 === child }
        }
    }

    // MARK: - Parser tables

    /// node-html-parser's `kMarkupPattern`, verbatim. The attribute group is
    /// what lets a quoted attribute value contain `>`.
    private static let markupPattern = try! NSRegularExpression(
        pattern: #"<!--[\s\S]*?-->|<(/?)([a-zA-Z][-.:0-9_a-zA-Z]*)"#
            + #"((?:\s+[^>]*?(?:(?:'[^']*')|(?:"[^"]*"))?)*)\s*(/?)>"#
    )

    private static let frameFlag = "documentfragmentcontainer"

    /// Elements whose body the parser takes verbatim instead of parsing.
    private static let rawTextTags: Set<String> = ["script", "noscript", "style", "pre"]

    private static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img",
        "input", "link", "meta", "param", "source", "track", "wbr",
    ]

    /// `kElementsClosedByOpening`: opening one of the values auto-closes an
    /// open element named by the key.
    private static let closedByOpening: [String: Set<String>] = [
        "li": ["li"], "p": ["p", "div"], "b": ["div"],
        "td": ["td", "th"], "th": ["td", "th"],
        "h1": ["h1"], "h2": ["h2"], "h3": ["h3"],
        "h4": ["h4"], "h5": ["h5"], "h6": ["h6"],
    ]

    /// `kElementsClosedByClosing`: closing one of the values auto-closes an
    /// open element named by the key.
    private static let closedByClosing: [String: Set<String>] = [
        "li": ["ul", "ol"], "a": ["div"], "b": ["div"], "i": ["div"],
        "p": ["div"], "td": ["tr", "table"], "th": ["tr", "table"],
    ]

    /// node-html-parser registers only the all-lowercase and all-uppercase
    /// spelling of each tag in its auto-close tables, so a mixed-case tag
    /// never matches one. Returns the lookup key, or nil for such a tag.
    private static func autoCloseKey(_ tag: String) -> String? {
        let lowercased = tag.lowercased()
        guard tag == lowercased || tag == tag.uppercased() else { return nil }
        return lowercased
    }

    private static func isVoid(_ tag: String) -> Bool {
        guard let key = autoCloseKey(tag) else { return false }
        return voidTags.contains(key)
    }

    // MARK: - Parsing

    private static func parse(_ xhtml: String) -> Node {
        // node-html-parser wraps the input so unbalanced markup cannot escape
        // the document; every offset below is into the wrapped string.
        let wrapped = "<\(frameFlag)>\(xhtml)</\(frameFlag)>"
        let data = wrapped as NSString
        let documentEnd = data.length - (frameFlag.utf16.count + 2)

        let root = Node(.root)
        var stack: [Node] = [root]
        var currentParent = root
        var lastTextPos = -1

        var pending = markupPattern.matches(
            in: wrapped, range: NSRange(location: 0, length: data.length)
        )
        var index = 0

        while index < pending.count {
            let match = pending[index]
            index += 1
            let tagStartPos = match.range.location
            let tagEndPos = match.range.location + match.range.length

            if lastTextPos > -1, lastTextPos < tagStartPos {
                currentParent.appendChild(Node(.text(data.substring(
                    with: NSRange(location: lastTextPos, length: tagStartPos - lastTextPos)
                ))))
            }
            lastTextPos = tagEndPos

            // A comment match has no tag groups. Comments are dropped: the
            // server re-parses each block's innerHTML with comments off.
            let tagRange = match.range(at: 2)
            guard tagRange.location != NSNotFound else { continue }
            let tagName = data.substring(with: tagRange)
            if tagName == frameFlag { continue }

            let isClosingTag = match.range(at: 1).length > 0
            var isSelfClosing = match.range(at: 4).length > 0

            if !isClosingTag {
                if !isSelfClosing, let parentTag = currentParent.tag,
                   let parentKey = autoCloseKey(parentTag),
                   let childKey = autoCloseKey(tagName),
                   closedByOpening[parentKey]?.contains(childKey) == true {
                    stack.removeLast()
                    currentParent = stack[stack.count - 1]
                }

                let element = Node(.element(tagName))
                currentParent.appendChild(element)
                currentParent = element
                stack.append(element)

                if rawTextTags.contains(tagName.lowercased()) {
                    let closeRange = data.range(
                        of: "</\(tagName)>",
                        options: .literal,
                        range: NSRange(location: tagEndPos, length: data.length - tagEndPos)
                    )
                    let bodyEnd = closeRange.location == NSNotFound
                        ? documentEnd
                        : closeRange.location
                    if bodyEnd > tagEndPos {
                        let body = data.substring(with: NSRange(
                            location: tagEndPos, length: bodyEnd - tagEndPos
                        ))
                        if body.unicodeScalars.contains(where: { !$0.isJavaScriptWhitespace }) {
                            element.appendChild(Node(.text(body)))
                        }
                    }
                    guard closeRange.location != NSNotFound else {
                        return repairingUnclosedElements(root: root, stack: &stack)
                    }
                    // Resume after the closing tag and treat the element as
                    // closed, exactly as node-html-parser does.
                    lastTextPos = closeRange.location + closeRange.length
                    (pending, index) = matches(in: wrapped, data, from: lastTextPos)
                    isSelfClosing = true
                }
            }

            guard isClosingTag || isSelfClosing || isVoid(tagName) else { continue }
            while true {
                if currentParent.tag == tagName {
                    stack.removeLast()
                    currentParent = stack[stack.count - 1]
                    break
                }
                guard let parentTag = currentParent.tag,
                      let childKey = autoCloseKey(tagName),
                      closedByClosing[parentTag.lowercased()]?.contains(childKey) == true
                else { break }
                stack.removeLast()
                currentParent = stack[stack.count - 1]
            }
        }

        return repairingUnclosedElements(root: root, stack: &stack)
    }

    /// Re-matches from `position` after the parser jumped over a raw-text
    /// element's body, so a `<` hidden inside that body cannot shift the
    /// tokens that follow it.
    private static func matches(
        in wrapped: String, _ data: NSString, from position: Int
    ) -> ([NSTextCheckingResult], Int) {
        guard position < data.length else { return ([], 0) }
        return (
            markupPattern.matches(
                in: wrapped,
                range: NSRange(location: position, length: data.length - position)
            ),
            0
        )
    }

    /// node-html-parser's post-parse repair of elements left open at EOF: the
    /// element is dropped and its children are adopted by its parent.
    private static func repairingUnclosedElements(root: Node, stack: inout [Node]) -> Node {
        while stack.count > 1 {
            let last = stack.removeLast()
            guard let oneBefore = stack.last else { break }
            guard let parent = last.parent, let grandparent = parent.parent else { continue }
            if parent === oneBefore, last.tag?.uppercased() == oneBefore.tag?.uppercased() {
                oneBefore.removeChild(last)
                for child in last.children { grandparent.appendChild(child) }
                stack.removeLast()
            } else {
                oneBefore.removeChild(last)
                for child in last.children { oneBefore.appendChild(child) }
            }
        }
        return root
    }
}
