import AuthenticationServices
import SwiftUI

/// The presentational pieces of `TranslationSheet`'s book page. They hold no
/// flow state: the sheet decides what is enabled and what a tap does.

/// Small uppercase caption over a value or a group.
struct TranslationPageLabel: View {
    let key: LocalizedStringKey
    let palette: BrandPalette

    var body: some View {
        Text(key)
            .font(Typography.control(10, weight: .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(palette.tertiaryText)
    }
}

/// App Store-style facts: length, reading time, source language, turnaround.
struct TranslationFactsStrip: View {
    let chapters: String
    let readingTime: String
    let original: String
    let readyIn: String
    let palette: BrandPalette

    var body: some View {
        HStack(spacing: 0) {
            cell("Length", value: chapters)
            divider
            cell("Reading time", value: readingTime)
            divider
            cell("Original", value: original)
            divider
            cell("Ready in", value: readyIn)
        }
        .padding(.vertical, Spacing.sm)
        .overlay(alignment: .top) { palette.hairline.frame(height: 0.5) }
        .overlay(alignment: .bottom) { palette.hairline.frame(height: 0.5) }
    }

    private func cell(_ label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 5) {
            TranslationPageLabel(key: label, palette: palette)
            Text(verbatim: value)
                .font(Typography.control(15, weight: .semibold))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        palette.hairline.frame(width: 0.5, height: 30)
    }
}

/// The one choice on the page, in the open: a chip per language, the
/// selected one filled. A language still being quality-checked says Beta.
struct TranslationLanguagePicker: View {
    let choices: [TranslationTargetLanguage]
    let selected: TranslationTargetLanguage
    let isSelectedApproved: Bool
    let isEnabled: Bool
    let palette: BrandPalette
    let onSelect: (TranslationTargetLanguage) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.xs) {
            TranslationPageLabel(key: "Translate into", palette: palette)
            HStack(spacing: Spacing.xs) {
                ForEach(choices, id: \.self) { chip($0) }
            }
            if !isSelectedApproved {
                Text("Beta: this language is still being quality-checked.")
                    .font(Typography.meta(12))
                    .foregroundStyle(palette.note)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("translation.targetLanguage")
    }

    private func chip(_ language: TranslationTargetLanguage) -> some View {
        let isSelected = language == selected
        return Button { onSelect(language) } label: {
            Text(verbatim: language.localizedName(in: locale))
                .font(Typography.control(14, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Color(hex: "#F7F5EE") : palette.text)
                .padding(.horizontal, Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(isSelected ? palette.accent : palette.surface, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).strokeBorder(isSelected ? .clear : palette.hairline))
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("translation.target.\(language.rawValue)")
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
