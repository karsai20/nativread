import SwiftUI

/// The app's icon set: Lucide (ISC), bundled as template SVGs under
/// Assets.xcassets/Lucide. Fixed sizes, tinted by foregroundStyle.
enum LucideIcon: String, CaseIterable {
    case accessibility = "accessibility"
    case aLargeSmall = "a-large-small"
    case alignJustify = "align-justify"
    case alignLeft = "align-left"
    case arrowRight = "arrow-right"
    case arrowUpRight = "arrow-up-right"
    case badgeCheck = "badge-check"
    case ban = "ban"
    case book = "book"
    case bookOpen = "book-open"
    case bookmark = "bookmark"
    case check = "check"
    case chevronDown = "chevron-down"
    case chevronLeft = "chevron-left"
    case chevronRight = "chevron-right"
    case chevronUp = "chevron-up"
    case circleX = "circle-x"
    case clock = "clock"
    case code = "code"
    case contrast = "contrast"
    case ellipsis = "ellipsis"
    case fileQuestion = "file-question"
    case fileSearch = "file-search"
    case fileText = "file-text"
    case foldVertical = "fold-vertical"
    case hand = "hand"
    case highlighter = "highlighter"
    case hourglass = "hourglass"
    case info = "info"
    case languages = "languages"
    case libraryBig = "library-big"
    case list = "list"
    case lock = "lock"
    case moon = "moon"
    case moonStar = "moon-star"
    case plus = "plus"
    case rotateCw = "rotate-cw"
    case search = "search"
    case settings2 = "settings-2"
    case share = "share"
    case sparkles = "sparkles"
    case square = "square"
    case squareArrowRight = "square-arrow-right"
    case squareCheck = "square-check"
    case stickyNote = "sticky-note"
    case sun = "sun"
    case sunDim = "sun-dim"
    case table = "table"
    case thermometerSun = "thermometer-sun"
    case trash2 = "trash-2"
    case triangleAlert = "triangle-alert"
    case type = "type"
    case unfoldVertical = "unfold-vertical"
    case userCheck = "user-check"
    case userX = "user-x"
    case wrench = "wrench"
    case x = "x"

    var image: Image { Image("lucide-\(rawValue)").renderingMode(.template) }
}

/// A Lucide glyph at a fixed point size, tinted by the current foreground style.
struct Icon: View {
    let icon: LucideIcon
    var size: CGFloat = 18
    init(_ icon: LucideIcon, size: CGFloat = 18) { self.icon = icon; self.size = size }
    var body: some View {
        icon.image.resizable().scaledToFit().frame(width: size, height: size)
    }
}
