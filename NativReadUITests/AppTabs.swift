import XCTest

/// Addressing the app's three destinations across device idioms.
///
/// On iPhone the UIKit tab bar drops the accessibility identifier SwiftUI sets
/// on a `tabItem`, so tabs can only be reached by position. On iPad the tab
/// bar is a floating control whose buttons *do* carry the identifier but which
/// is not exposed as a `tabBar` element at all. This picks whichever query the
/// running idiom actually offers.
enum AppTab: Int, CaseIterable {
    case library, translate, settings

    var identifier: String {
        switch self {
        case .library: return "tab.library"
        case .translate: return "tab.translate"
        case .settings: return "tab.settings"
        }
    }
}

extension XCUIApplication {
    func tabButton(_ tab: AppTab) -> XCUIElement {
        // iPad nests each tab button inside an identically identified
        // container, so the query matches twice — take the first.
        let identified = buttons.matching(
            identifier: tab.identifier
        ).firstMatch
        if identified.exists { return identified }
        return tabBars.buttons.element(boundBy: tab.rawValue)
    }
}
