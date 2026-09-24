import Foundation
import ObjectiveC

/// Routes `Bundle.main` string lookups to a chosen `.lproj` so the in-app
/// language switch takes effect everywhere — not just where we call
/// `LocalizationStore.localizedString` explicitly.
///
/// **Why this is needed:** SwiftUI `Text("literal")` resolves through
/// `Bundle.main.localizedString(forKey:value:table:)`, which uses the
/// *bundle's* preferred localization (driven by the device language), **not**
/// the `\.environment(\.locale)` we inject. Swizzling the main bundle's class
/// so its lookups defer to the selected `.lproj` makes `Text` follow the
/// user's choice. `String(localized:)` does not go through that lookup, so it
/// takes the `.lproj` explicitly: `String(localized: "…", bundle: .appLanguage)`.
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

    /// The `.lproj` of the in-app language, or `main` when following the
    /// device. Pass it to every `String(localized:)`: unlike `Text`, that API
    /// resolves without going through the swizzled lookup, so on its own it
    /// stays in the device language.
    static var appLanguage: Bundle {
        objc_getAssociatedObject(Bundle.main, &overrideKey) as? Bundle ?? .main
    }

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
