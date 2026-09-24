import AuthenticationServices
import SwiftUI

/// The presentational pieces of `TranslationSheet`'s book page. They hold no
/// flow state: the sheet decides what is enabled and what a tap does.

/// The book's facts as a 2×2 grid of small bordered cards: a muted label
/// with its icon over the value, the way a shadcn stat card reads.
struct TranslationFactsGrid: View {
    let chapters: String
    let readingTime: String
    let original: String
    let readyIn: String
    let palette: BrandPalette

    var body: some View {
        Grid(horizontalSpacing: Spacing.xs, verticalSpacing: Spacing.xs) {
            GridRow {
                card(.bookOpen, "Length", value: chapters)
                card(.clock, "Reading time", value: readingTime)
            }
            GridRow {
                card(.languages, "Original", value: original)
                card(.hourglass, "Ready in", value: readyIn)
            }
        }
    }

    private func card(_ icon: LucideIcon, _ label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Icon(icon, size: 13)
                Text(label)
                    .font(Typography.meta(12))
                    .lineLimit(1)
            }
            .foregroundStyle(palette.secondaryText)
            Text(verbatim: value)
                .font(Typography.control(16, weight: .semibold))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm - 2)
        .background(palette.surface, in: cardShape)
        .overlay(cardShape.strokeBorder(palette.hairline))
        .accessibilityElement(children: .combine)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
    }
}

/// The one choice on the page, as a shadcn-style select: a bordered field
/// showing the chosen language, opening the system menu of every target on
/// offer. A language still being quality-checked carries a Beta badge.
struct TranslationLanguagePicker: View {
    let choices: [TranslationTargetLanguage]
    let selected: TranslationTargetLanguage
    let isApproved: (TranslationTargetLanguage) -> Bool
    let isEnabled: Bool
    let palette: BrandPalette
    let onSelect: (TranslationTargetLanguage) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Translate into")
                .font(Typography.control(13, weight: .medium))
                .foregroundStyle(palette.secondaryText)
            Menu {
                ForEach(choices, id: \.self) { menuItem($0) }
            } label: {
                field
            }
            .disabled(!isEnabled)
            .accessibilityIdentifier("translation.targetLanguage")
            if !isApproved(selected) {
                Text("Beta: this language is still being quality-checked.")
                    .font(Typography.meta(12))
                    .foregroundStyle(palette.note)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var field: some View {
        HStack(spacing: Spacing.xs) {
            Icon(.languages, size: 16)
                .foregroundStyle(palette.secondaryText)
            Text(verbatim: selected.localizedName(in: locale))
                .font(Typography.control(15, weight: .medium))
                .foregroundStyle(palette.text)
                .lineLimit(1)
            if !isApproved(selected) { betaBadge }
            Spacer(minLength: 0)
            Icon(.chevronDown, size: 16)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(minHeight: 44)
        .background(palette.surface, in: fieldShape)
        .overlay(fieldShape.strokeBorder(palette.hairline))
        .opacity(isEnabled ? 1 : 0.5)
        .contentShape(fieldShape)
    }

    private var betaBadge: some View {
        Text("Beta")
            .font(Typography.control(11, weight: .semibold))
            .foregroundStyle(palette.note)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule(style: .continuous).strokeBorder(palette.note.opacity(0.5)))
    }

    /// A system menu row: a checkmark on the chosen language, "Beta" as the
    /// subtitle of one still being quality-checked.
    private func menuItem(_ language: TranslationTargetLanguage) -> some View {
        Button { onSelect(language) } label: {
            if language == selected {
                Label(language.localizedName(in: locale), systemImage: "checkmark")
            } else {
                Text(verbatim: language.localizedName(in: locale))
            }
            if !isApproved(language) { Text("Beta") }
        }
        .accessibilityIdentifier("translation.target.\(language.rawValue)")
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
    }
}

/// The free first chapter: a real second button, the way a store puts
/// "Sample" beside "Buy" — it is the cheapest way in, not fine print.
struct TranslationSampleButton: View {
    let isOnShelf: Bool
    let isEnabled: Bool
    let palette: BrandPalette
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isOnShelf { Icon(.check, size: 13) }
                Text(isOnShelf ? "First chapter on your shelf" : "First chapter free")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(Typography.control(15, weight: .semibold))
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(palette.surface, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(palette.hairline))
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
        .disabled(!isEnabled)
        .accessibilityIdentifier("translation.freeChapter")
    }
}

/// The rights attestation, as fine print the action refers to. Tapping
/// Translate or the free chapter is the acceptance; the sheet records it.
struct TranslationFinePrint: View {
    let palette: BrandPalette
    let onTerms: () -> Void

    var body: some View {
        Text(text)
            .font(Typography.control(11))
            .foregroundStyle(palette.tertiaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { _ in
                onTerms()
                return .handled
            })
            .accessibilityIdentifier("translation.terms.link")
    }

    private var text: AttributedString {
        let markdown = String(localized: "Yours for good, no subscription · by continuing you confirm you own this book · [Terms of Use](nativread://terms)", bundle: .appLanguage)
        guard var text = try? AttributedString(markdown: markdown) else {
            return AttributedString(markdown)
        }
        for run in text.runs where run.link != nil {
            text[run.range].foregroundColor = palette.secondaryText
            text[run.range].underlineStyle = .single
        }
        return text
    }
}

/// Sign in with Apple, brought forward once the reader reaches for an action.
struct TranslationAccountSection: View {
    let palette: BrandPalette
    /// DEBUG only, against a loopback/LAN backend: skip Apple for testing.
    let onUseLocalTestAccount: () -> Void

    @Environment(TranslationAuthStore.self) private var auth
    @Environment(SettingsStore.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Spacing.sm) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = []
            } onCompletion: { result in
                guard let backendURL = settings.translationBackendURL else { return }
                Task { await auth.completeAppleSignIn(result, backendURL: backendURL) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(Capsule(style: .continuous))
            .disabled(auth.isSigningIn || settings.translationBackendURL == nil)
            .accessibilityIdentifier("translation.signInWithApple")

            if auth.isSigningIn {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .tint(palette.accent)
                    caption(Text("Signing in securely..."))
                }
            } else if let errorMessage = auth.errorMessage {
                // Already final text from the backend; not a catalog key.
                caption(Text(verbatim: errorMessage))
            } else {
                caption(Text("Sign in with Apple to start — it ties the purchase to you, nothing else."))
            }

#if DEBUG
            if settings.isPrivateTestTranslationBackend {
                AppPrimaryButton(
                    title: "Use local placeholder account",
                    tone: .secondary,
                    action: onUseLocalTestAccount,
                    palette: palette
                )
                .accessibilityIdentifier("translation.localTestAccount")
            }
#endif
        }
    }

    private func caption(_ text: Text) -> some View {
        text
            .font(Typography.meta())
            .foregroundStyle(palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
    }
}

/// What the page says while a job runs: the kicker over the title and the
/// capsule's label and fill, from the job and the upload's own progress.
struct TranslationProgressLabels {
    let job: TranslationJob
    /// Fraction of the book sent so far, or `nil` when no upload is running.
    let uploadProgress: Double?
    let locale: Locale

    var capsuleTitle: String {
        switch job.phase {
        case .uploading:
            if let uploadProgress {
                return uploadProgress < 1
                    ? String(localized: "Uploading \(Int(uploadProgress * 100))%…", bundle: .appLanguage)
                    : String(localized: "Measuring the book…", bundle: .appLanguage)
            }
            return String(localized: "Uploading…", bundle: .appLanguage)
        case .translating:
            return sectionsText ?? String(localized: "Translating…", bundle: .appLanguage)
        case .importingResult:
            return String(localized: "Adding to your shelf…", bundle: .appLanguage)
        default:
            return ""
        }
    }

    var capsuleProgress: Double? {
        switch job.phase {
        case .uploading: return uploadProgress ?? 0
        case .translating:
            guard let done = job.translatedChunks, let total = job.totalChunks, total > 0 else { return 0.02 }
            return Double(done) / Double(total)
        case .importingResult: return 0.97
        default: return nil
        }
    }

    var headline: LocalizedStringKey {
        switch job.phase {
        case .draft, .attested:
            return ""
        case .uploading:
            return "Uploading"
        case .translating:
            return job.errorMessage == nil ? "Translating" : "Reconnecting"
        case .importingResult:
            return "Adding to your shelf"
        case .finished:
            return "Ready to read"
        case .failed:
            return "Translation stopped"
        }
    }

    /// "12/40 sections", localized. Only once the backend reports chunks.
    private var sectionsText: String? {
        guard let done = job.translatedChunks,
              let total = job.totalChunks,
              total > 0
        else { return nil }
        return String.localizedStringWithFormat(
            String(localized: "%lld/%lld sections", bundle: .appLanguage, locale: locale),
            done,
            total
        )
    }
}
