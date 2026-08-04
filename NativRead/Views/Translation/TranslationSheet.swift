import AuthenticationServices
import StoreKit
import SwiftUI

struct TranslationSheet: View {
    let book: Book

    @Environment(LibraryStore.self) private var library
    @Environment(SettingsStore.self) private var settings
    @Environment(TranslationStore.self) private var translations
    @Environment(TranslationAuthStore.self) private var auth
    @Environment(BookPurchaseStore.self) private var purchases
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    @State private var hasAcceptedTerms = false
    @State private var isRequestingTranslation = false
    @State private var detectedLanguage: DetectedBookLanguage = .unknown
    @State private var usesLocalTestAccount = false
    @State private var fullQuote: TranslationBackendClient.UploadResponse?
    @State private var bookProduct: Product?
    @State private var isEntitledToFullBook = false
    @State private var pricingError: String?
    @State private var showsWholeBookOptions = false
    @State private var pendingAITranslation: PendingAITranslation?

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var job: TranslationJob {
        translations.job(for: book)
    }

    private var clickwrapCopy: TranslationClickwrapCopy {
        locale.language.languageCode?.identifier == "hu" ? .hungarian : .english
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pinned so "Done" stays reachable however far the sheet
                // scrolls — the nav bar it replaces behaved the same way.
                AppSheetHeader(
                    title: "Translate",
                    onDone: { dismiss() },
                    palette: palette
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        header
                        heroCard
                        freeChapterSection
                        if hasAcceptedTerms && hasBackendIdentity {
                            purchaseSection
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(palette.background.ignoresSafeArea())
            // Hidden on the root only, so pushed destinations (Terms of Use)
            // keep their own bar and back button.
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("translation.sheet")
        .sheet(item: $pendingAITranslation) { pending in
            AIProcessingConsentView(
                providerName: TranslationPrivacy.aiProviderName
            ) {
                translations.recordAIProcessingConsent(for: book)
                pendingAITranslation = nil
                requestTranslation(
                    kind: pending.kind,
                    preparedUpload: pending.preparedUpload
                )
            }
        }
        .onAppear {
            hasAcceptedTerms = translations.currentTermsAcceptance(for: book) != nil
            detectedLanguage = DetectedBookLanguage.detect(
                from: library.languageDetectionSample(for: book)
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(book.title)
                .font(Typography.display(28))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(book.author)
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        }
    }

    /// One card says everything above the fold: what you get (first chapter,
    /// free) and which way the translation runs. The target is fixed until a
    /// second language ships, so a single line replaces the old pair card.
    private var heroCard: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 48, height: 48)
                .background(palette.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("First chapter free")
                    .font(Typography.control(18, weight: .semibold))
                    .foregroundStyle(palette.text)

                Text(verbatim: languagePairText)
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                .strokeBorder(palette.hairline, lineWidth: Spacing.hairlineWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("translation.hero")
    }

    /// "English → Magyar", or just the target when detection came up empty.
    private var languagePairText: String {
        let target = localizedName(for: job.targetLanguage)
        switch detectedLanguage {
        case .language(let code, let fallbackName, _):
            let source = (locale.localizedString(forLanguageCode: code)
                ?? fallbackName).capitalized
            return "\(source) → \(target)"
        case .unknown:
            return "→ \(target)"
        }
    }

    private var termsAcceptanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                hasAcceptedTerms.toggle()
                if hasAcceptedTerms {
                    translations.recordTermsAcceptance(
                        for: book,
                        localeIdentifier: locale.identifier
                    )
                } else {
                    translations.clearTermsAcceptance(for: book)
                }
            } label: {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(
                        systemName: hasAcceptedTerms
                            ? "checkmark.square.fill" : "square"
                    )
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28, height: 28)

                    Text(clickwrapCopy.attestation)
                        .font(Typography.body(16))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("translation.termsAcceptance")
            .accessibilityAddTraits(hasAcceptedTerms ? [.isSelected] : [])
            .accessibilityValue(
                hasAcceptedTerms ? clickwrapCopy.accepted : clickwrapCopy.notAccepted
            )

            NavigationLink {
                TermsOfUseView()
            } label: {
                Label(clickwrapCopy.termsLink, systemImage: "doc.text")
                    .font(Typography.control(16, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(minHeight: Spacing.minTapTarget)
            }
            .accessibilityIdentifier("translation.terms.link")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
        )
    }

    private var freeChapterSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if showsPhaseMessage {
                progressCard
            }

            if !job.isBackendActive && !job.hasFullTranslation {
                termsAcceptanceSection
            }

            if !job.hasFreePreview && !job.isBackendActive {
                if hasAcceptedTerms && !hasBackendIdentity {
                    accountSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            AppPrimaryButton(
                title: freePreviewButtonTitle,
                systemImage: "sparkles",
                isEnabled: hasAcceptedTerms
                    && hasBackendIdentity
                    && !isRequestingTranslation
                    && !job.isBackendActive
                    && !job.hasFreePreview
                    && book.isTranslatableSource,
                action: { beginTranslation(kind: .preview) },
                palette: palette
            )
            .accessibilityIdentifier("translation.freeChapter")

            Text("The translation arrives as a separate book on your shelf. Your original stays unchanged.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeInOut(duration: 0.22), value: hasAcceptedTerms)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Sign in with Apple to start.")
                .font(Typography.body(16))
                .foregroundStyle(palette.text)

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = []
            } onCompletion: { result in
                guard let backendURL = settings.translationBackendURL else {
                    return
                }
                Task {
                    await auth.completeAppleSignIn(
                        result, backendURL: backendURL
                    )
                }
            }
            .signInWithAppleButtonStyle(
                colorScheme == .dark ? .white : .black
            )
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(
                auth.isSigningIn
                    || settings.translationBackendURL == nil
            )
            .accessibilityIdentifier("translation.signInWithApple")

            if auth.isSigningIn {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .tint(palette.accent)
                    phaseText("Signing in securely...")
                }
            } else if let errorMessage = auth.errorMessage {
                Label {
                    Text(verbatim: errorMessage)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
            }

#if DEBUG
            if isPrivateTestBackend {
                AppPrimaryButton(
                    title: "Use local placeholder account",
                    tone: .secondary,
                    action: {
                        usesLocalTestAccount = true
                        pricingError = nil
                    },
                    palette: palette
                )
                .accessibilityIdentifier("translation.localTestAccount")
            }
#endif
        }
    }

    /// The chevron that marks an expandable row. Rows carrying their own
    /// trailing control suppress `AppSettingsRow`'s navigation chevron, so
    /// this one stands in and rotates with the disclosure.
    private func disclosureChevron(isOpen: Bool) -> some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.secondaryText)
            .rotationEffect(.degrees(isOpen ? 180 : 0))
    }

    private var freePreviewButtonTitle: LocalizedStringKey {
        job.hasFreePreview ? "Free chapter already added" : "Translate first chapter"
    }

    private var showsPhaseMessage: Bool {
        switch job.phase {
        case .draft, .attested:
            return false
        case .uploading, .translating, .importingResult, .finished, .failed:
            return true
        }
    }

    private func localizedName(
        for language: TranslationTargetLanguage
    ) -> String {
        let name = locale.localizedString(forLanguageCode: language.rawValue)
            ?? language.displayName
        return name.capitalized
    }

    /// One card carries the whole run: a headline for where the job stands, a
    /// determinate track once the backend reports chunk counts, and the
    /// phase's own sentence underneath.
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(progressHeadline)
                .font(Typography.control(21, weight: .bold))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)

            if let fraction = job.progressFraction {
                AppProgressTrack(value: fraction, palette: palette)
            } else if job.isBackendActive {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(palette.accent)
            }

            phaseMessage
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.accentSoft)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
        )
    }

    private var progressHeadline: LocalizedStringKey {
        switch job.phase {
        case .draft, .attested:
            return ""
        case .uploading:
            return "Uploading"
        case .translating:
            return job.errorMessage == nil ? "Translating" : "Reconnecting"
        case .importingResult:
            return "Adding to your library"
        case .finished:
            return "Ready to read"
        case .failed:
            return "Translation stopped"
        }
    }

    @ViewBuilder
    private var phaseMessage: some View {
        switch job.phase {
        case .draft, .attested:
            EmptyView()
        case .uploading:
            phaseText("Uploading EPUB to translator...")
        case .translating:
            if let reconnectMessage = job.errorMessage {
                phaseText(verbatim: reconnectMessage)
            } else if let sections = sectionsText {
                phaseText(verbatim: sections)
            } else {
                phaseText("You can close the app. We keep translating.")
            }
        case .importingResult:
            // The headline ("Adding to your library") already says it all.
            EmptyView()
        case .finished:
            phaseText("Added to your library.")
        case .failed:
            if let errorMessage = job.errorMessage {
                phaseText(verbatim: errorMessage)
            } else {
                phaseText("Translation failed.")
            }
        }
    }

    /// "12/40 sections", localized. Only once the backend reports chunks.
    private var sectionsText: String? {
        guard let done = job.translatedChunks,
              let total = job.totalChunks,
              total > 0
        else { return nil }
        return String.localizedStringWithFormat(
            String(localized: "%lld/%lld sections", locale: locale),
            done,
            total
        )
    }

    private func phaseText(_ text: LocalizedStringKey) -> some View {
        phaseTextStyle(Text(text))
    }

    /// Backend-supplied messages are already in their final form — routing
    /// them through the catalog would only look for a key that isn't there.
    private func phaseText(verbatim text: String) -> some View {
        phaseTextStyle(Text(verbatim: text))
    }

    private func phaseTextStyle(_ text: Text) -> some View {
        text
            .font(Typography.meta())
            .foregroundStyle(palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purchaseSection: some View {
        AppSettingsSection(palette: palette) {
            AppSettingsRow(
                systemImage: "book.closed",
                title: "Whole book",
                hidesSeparator: !showsWholeBookOptions,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsWholeBookOptions.toggle()
                    }
                },
                palette: palette,
                trailing: { disclosureChevron(isOpen: showsWholeBookOptions) }
            )
            .accessibilityIdentifier("translation.fullBookDisclosure")

            if showsWholeBookOptions {
                purchaseOptions
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var purchaseOptions: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if fullQuote?.quote != nil {
                // No price means the backend is not selling this book — a
                // self-hosted deployment with entitlements turned off. Nothing
                // to buy, so the translation is simply available.
                if isEntitledToFullBook || fullQuote?.price == nil {
                    AppPrimaryButton(
                        title: fullBookButtonTitle,
                        systemImage: "book.closed",
                        isEnabled: !isRequestingTranslation && !job.isBackendActive,
                        action: {
                            guard let fullQuote else { return }
                            beginTranslation(
                                kind: .full, preparedUpload: fullQuote
                            )
                        },
                        palette: palette
                    )
                    .accessibilityIdentifier("translation.fullBook")
                } else if let bookProduct {
                    // The price always comes from StoreKit, never from our own
                    // tier table: it is the only source that is localized and
                    // matches what the App Store will actually charge.
                    AppPrimaryButton(
                        title: "Translate whole book · \(bookProduct.displayPrice)",
                        systemImage: "cart",
                        isEnabled: !isRequestingTranslation && !purchases.isPurchasing,
                        action: { buyFullBook(bookProduct) },
                        palette: palette
                    )
                    .accessibilityIdentifier("translation.purchaseFullBook")

                    Text("One purchase per book. Buy it once and it stays yours — reinstall the app and it comes back.")
                        .font(Typography.meta())
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Loading the price…")
                        .font(Typography.meta())
                        .foregroundStyle(palette.secondaryText)
                }
            } else {
                AppPrimaryButton(
                    title: "Calculate exact quote",
                    systemImage: "number",
                    tone: .secondary,
                    isEnabled: hasAcceptedTerms
                        && hasBackendIdentity
                        && !isRequestingTranslation
                        && !job.isBackendActive
                        && !job.hasFullTranslation
                        && book.isTranslatableSource,
                    action: { prepareFullQuote() },
                    palette: palette
                )
                .accessibilityIdentifier("translation.calculateQuote")
            }

            if let pricingError {
                Label {
                    Text(verbatim: pricingError)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
            }
        }
    }

    private var fullBookButtonTitle: LocalizedStringKey {
        job.hasFullTranslation ? "Full translation already added" : "Translate whole book"
    }


    private func requestTranslation(
        kind: TranslationRequestKind,
        preparedUpload: TranslationBackendClient.UploadResponse? = nil
    ) {
        guard kind == .full || !job.hasFreePreview else { return }
        guard kind == .preview || !job.hasFullTranslation else { return }
        // Acceptance is an explicit legal gate; never set it programmatically.
        // The buttons are already disabled until the user checks the box.
        guard hasAcceptedTerms else { return }
        guard let termsAcceptance = translations.currentTermsAcceptance(
            for: book
        ) else { return }
        guard job.acceptedAIProcessingVersion ==
                TranslationPrivacy.currentAIConsentVersion
        else { return }
        guard book.format == .epub else {
            translations.markBackendFailed(
                for: book,
                message: TranslationBackendClient.ClientError
                    .unsupportedFormat.localizedDescription
            )
            return
        }
        guard let client = backendClient else {
            translations.markBackendFailed(
                for: book,
                message: TranslationBackendClient.ClientError
                    .invalidBackendURL.localizedDescription
            )
            return
        }

        isRequestingTranslation = true
        let targetLanguage = job.targetLanguage
        let sourceURL = library.storedFileURL(for: book)
        if preparedUpload == nil {
            translations.markBackendUploadStarted(for: book, kind: kind)
        }

        Task {
            do {
                let upload: TranslationBackendClient.UploadResponse
                if let preparedUpload {
                    upload = preparedUpload
                } else {
                    upload = try await client.upload(epubURL: sourceURL)
                }
                let shouldStartTranslation =
                    upload.alreadyTranslated != true
                if shouldStartTranslation {
                    translations.markBackendTranslationStarted(
                        for: book,
                        backendJobID: upload.id,
                        kind: kind
                    )
                    try await client.start(
                        jobID: upload.id,
                        sample: kind == .preview,
                        targetLanguage: targetLanguage,
                        termsAcceptance: termsAcceptance
                    )
                    _ = try await client.waitUntilDone(jobID: upload.id) {
                        status in
                        await MainActor.run {
                            translations.updateBackendProgress(
                                for: book,
                                translatedChunks: status.chunks?.done,
                                totalChunks: status.chunks?.total
                            )
                        }
                    }
                }
                translations.markBackendImportStarted(for: book, kind: kind)
                let output = try await client.downloadResult(jobID: upload.id)
                try TranslationResultImporter.importResult(
                    output,
                    title: upload.title ?? book.title,
                    book: book,
                    kind: kind,
                    targetLanguage: targetLanguage,
                    library: library
                )
                translations.markBackendFinished(for: book, kind: kind)
                if kind == .full { fullQuote = nil }
            } catch {
                handleTranslationError(error)
            }
            isRequestingTranslation = false
        }
    }

    private func beginTranslation(
        kind: TranslationRequestKind,
        preparedUpload: TranslationBackendClient.UploadResponse? = nil
    ) {
        guard hasAcceptedTerms, hasBackendIdentity else { return }
        guard job.acceptedAIProcessingVersion ==
                TranslationPrivacy.currentAIConsentVersion
        else {
            pendingAITranslation = PendingAITranslation(
                kind: kind,
                preparedUpload: preparedUpload
            )
            return
        }
        requestTranslation(kind: kind, preparedUpload: preparedUpload)
    }

    private func prepareFullQuote() {
        guard hasAcceptedTerms, let client = backendClient else { return }
        guard book.format == .epub else { return }
        pricingError = nil
        isRequestingTranslation = true
        translations.markBackendUploadStarted(for: book, kind: .full)
        let sourceURL = library.storedFileURL(for: book)

        Task {
            do {
                let upload = try await client.upload(epubURL: sourceURL)
                guard upload.quote != nil else {
                    throw TranslationBackendClient.ClientError.invalidResponse
                }
                fullQuote = upload
                isEntitledToFullBook = upload.entitledLanguages?.contains("hu") ?? false
                if !isEntitledToFullBook, let price = upload.price {
                    bookProduct = try? await purchases.product(for: price.productId)
                }
                translations.markBackendQuoteReady(
                    for: book, backendJobID: upload.id
                )
            } catch {
                pricingError = error.localizedDescription
                translations.markBackendFailed(
                    for: book, message: error.localizedDescription
                )
            }
            isRequestingTranslation = false
        }
    }

    private func buyFullBook(_ product: Product) {
        guard let fullQuote, let appAccountToken = auth.appAccountToken else { return }
        pricingError = nil
        Task {
            do {
                switch try await purchases.purchase(
                    product,
                    jobID: fullQuote.id,
                    appAccountToken: appAccountToken
                ) {
                case .entitled:
                    isEntitledToFullBook = true
                    beginTranslation(kind: .full, preparedUpload: fullQuote)
                case .cancelled:
                    break
                case .pending:
                    pricingError = "This purchase needs approval. The translation starts once it is approved."
                }
            } catch {
                pricingError = error.localizedDescription
            }
        }
    }

    private var hasBackendIdentity: Bool {
        auth.isSignedIn || usesLocalTestAccount
    }

    private var backendClient: TranslationBackendClient? {
        guard let backendURL = settings.translationBackendURL else { return nil }
        if let sessionToken = auth.sessionToken {
            return TranslationBackendClient(
                baseURL: backendURL, bearerToken: sessionToken
            )
        }
#if DEBUG
        if usesLocalTestAccount && isPrivateTestBackend {
            return TranslationBackendClient(
                baseURL: backendURL, userID: settings.translationUserID
            )
        }
#endif
        return nil
    }

    private var isPrivateTestBackend: Bool {
#if DEBUG
        guard let host = settings.translationBackendURL?.host?.lowercased()
        else { return false }
        if host == "localhost" || host == "::1" || host.hasPrefix("127.") {
            return true
        }
        if host.hasPrefix("10.") || host.hasPrefix("192.168.") {
            return true
        }
        let parts = host.split(separator: ".").compactMap {
            Int(String($0))
        }
        return parts.count == 4 && parts[0] == 172
            && (16...31).contains(parts[1])
#else
        return false
#endif
    }

    private func handleTranslationError(_ error: Error) {
        let current = translations.job(for: book)
        let canReconnect = current.backendJobID != nil
            && current.activeRequestKind != nil
            && (current.phase == .translating
                || current.phase == .importingResult)
        if canReconnect {
            if let clientError = error as? TranslationBackendClient.ClientError {
                switch clientError {
                case .failedStatus, .server:
                    translations.markBackendFailed(
                        for: book, message: error.localizedDescription
                    )
                    return
                default:
                    break
                }
            }
            translations.markBackendReconnectNeeded(
                for: book,
                message: "Translation continues on the backend. "
                    + "NativRead will reconnect automatically."
            )
        } else {
            translations.markBackendFailed(
                for: book, message: error.localizedDescription
            )
        }
    }
}

private struct TranslationClickwrapCopy {
    let attestation: String
    let termsLink: String
    let accepted: String
    let notAccepted: String

    static let english = TranslationClickwrapCopy(
        attestation: "I accept the Terms of Use.",
        termsLink: "Read the Terms of Use",
        accepted: "Accepted",
        notAccepted: "Not accepted"
    )

    static let hungarian = TranslationClickwrapCopy(
        attestation: "Elfogadom a Felhasználási feltételeket.",
        termsLink: "Felhasználási feltételek elolvasása",
        accepted: "Elfogadva",
        notAccepted: "Nincs elfogadva"
    )
}

private struct PendingAITranslation: Identifiable {
    let id = UUID()
    let kind: TranslationRequestKind
    let preparedUpload: TranslationBackendClient.UploadResponse?
}

private extension TranslationJob {
    var hasFreePreview: Bool {
        previewCompletedAt != nil
    }

    var hasFullTranslation: Bool {
        fullCompletedAt != nil
    }

    /// Only defined once the backend has reported chunk counts; until then the
    /// card shows an indeterminate bar rather than a fake zero.
    var progressFraction: Double? {
        guard let translatedChunks,
              let totalChunks,
              totalChunks > 0
        else { return nil }
        return Double(translatedChunks) / Double(totalChunks)
    }

    var isBackendActive: Bool {
        switch phase {
        case .uploading, .translating, .importingResult:
            return true
        default:
            return false
        }
    }
}
