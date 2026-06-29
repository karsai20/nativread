import Foundation
import ObjectiveC

/// Routes `Bundle.main` string lookups to a chosen `.lproj` so the in-app
/// language switch takes effect everywhere — not just where we call
/// `LocalizationStore.localizedString` explicitly.
///
/// **Why this is needed:** SwiftUI `Text("literal")` and `String(localized:)`
/// resolve through `Bundle.main.localizedString(forKey:value:table:)`, which
/// uses the *bundle's* preferred localization (driven by the device language),
/// **not** the `\.environment(\.locale)` we inject. Injecting the locale fixes
/// number/date formatting but leaves `Text` literals in the device language.
/// Swizzling the main bundle's class so its lookups defer to the selected
/// `.lproj` makes every localized string follow the user's choice.
///
/// Standard, App-Store-safe technique. Call `Bundle.setAppLanguage(_:)` once at
/// launch and again whenever the language changes; it is idempotent.
final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(
        forKey key: String, value: String?, table tableName: String?
    ) -> String {
        guard let override = objc_getAssociatedObject(self, &Bundle.overrideKey)
            as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return override.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    fileprivate static var overrideKey: UInt8 = 0

    /// Points `Bundle.main` at the `.lproj` for `languageCode`. Pass `nil`
    /// (the `.system` case) to fall back to the device's own language.
    static func setAppLanguage(_ languageCode: String?) {
        // Re-class the main bundle once so its lookups route through the
        // associated override bundle. Idempotent on repeat calls.
        if !(Bundle.main is LocalizedBundle) {
            object_setClass(Bundle.main, LocalizedBundle.self)
        }
        let override: Bundle? = {
            guard let languageCode,
                  let path = Bundle.main.path(
                      forResource: languageCode, ofType: "lproj"
                  ),
                  let bundle = Bundle(path: path) else {
                return nil
            }
            return bundle
        }()
        objc_setAssociatedObject(
            Bundle.main, &overrideKey, override, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}
