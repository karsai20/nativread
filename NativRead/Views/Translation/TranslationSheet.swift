import AuthenticationServices
import SwiftUI

struct TranslationSheet: View {
    let book: Book

    @Environment(LibraryStore.self) private var library
    @Environment(SettingsStore.self) private var settings
    @Environment(TranslationStore.self) private var translations
    @Environment(TranslationAuthStore.self) private var auth
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    @State private var hasAcceptedTerms = false
    @State private var isRequestingTranslation = false
    @State private var detectedLanguage: DetectedBookLanguage = .unknown
    @State private var usesLocalTestAccount = false
    @State private var fullQuote: TranslationBackendClient.UploadResponse?
    @State private var creditState: TranslationBackendClient.CreditsResponse?
    @State private var pricingError: String?
    @State private var showsTranslationDetails = false
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
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    freePreviewCard
                    languageSection
                    freeChapterSection
                    translationDetails
#if DEBUG
                    if hasAcceptedTerms && hasBackendIdentity {
                        purchaseSection
                    }
#endif
                }
                .padding(Spacing.lg)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Translate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(palette.accent)
                }
            }
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

    private var freePreviewCard: some View {
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

                Text("Try the translation before deciding.")
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
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Translate to")

            if TranslationTargetLanguage.passed.count > 1 {
                Picker(
                    "Translate to",
                    selection: Binding(
                        get: { job.targetLanguage },
                        set: { translations.setTargetLanguage($0, for: book) }
                    )
                ) {
                    ForEach(TranslationTargetLanguage.passed, id: \.self) { language in
                        Text(localizedName(for: language)).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(job.isBackendActive)
                .accessibilityIdentifier("translation.targetLanguage")
            } else {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(palette.accent)
                    Text(localizedName(for: job.targetLanguage))
                        .font(Typography.control(17, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 52)
                .background(palette.surface)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: Spacing.radiusSmall,
                        style: .continuous
                    )
                )
                .accessibilityIdentifier("translation.targetLanguage")
            }

            HStack(spacing: Spacing.xs) {
                Image(systemName: "text.magnifyingglass")
                Text("Detected source")
                Text("·")
                Text(localizedSourceLanguage)
            }
            .font(Typography.meta())
            .foregroundStyle(palette.secondaryText)
        }
    }

    private var termsAcceptanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(clickwrapCopy.title)
                .font(Typography.control(17, weight: .semibold))
                .foregroundStyle(palette.text)

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
                phaseMessage
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

            Button {
                beginTranslation(kind: .preview)
            } label: {
                Label(freePreviewButtonTitle, systemImage: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 30)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .disabled(
                !hasAcceptedTerms
                    || !hasBackendIdentity
                    || isRequestingTranslation
                    || job.isBackendActive
                    || job.hasFreePreview
                    || !book.isTranslatableSource
            )
            .accessibilityIdentifier("translation.freeChapter")
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
                progressMessage("Signing in securely...")
            } else if let errorMessage = auth.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }

#if DEBUG
            if isPrivateTestBackend {
                Button("Use local placeholder account") {
                    usesLocalTestAccount = true
                    pricingError = nil
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("translation.localTestAccount")
            }
#endif
        }
    }

    private var translationDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsTranslationDetails.toggle()
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(palette.accent)
                    Text("How translation works")
                        .font(Typography.control(16, weight: .medium))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .rotationEffect(.degrees(showsTranslationDetails ? 180 : 0))
                }
                .frame(minHeight: Spacing.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("translation.details")

            if showsTranslationDetails {
                Text("Your original book stays unchanged. The first reading chapter is translated and added to your library as a separate book.")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
        )
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

    private var localizedSourceLanguage: String {
        switch detectedLanguage {
        case .language(let code, let fallbackName, _):
            let name = locale.localizedString(forLanguageCode: code)
                ?? fallbackName
            return name.capitalized
        case .unknown:
            return String(localized: "Not detected", locale: locale)
        }
    }

    private func localizedName(
        for language: TranslationTargetLanguage
    ) -> String {
        let name = locale.localizedString(forLanguageCode: language.rawValue)
            ?? language.displayName
        return name.capitalized
    }

    @ViewBuilder
    private var phaseMessage: some View {
        switch job.phase {
        case .draft, .attested:
            EmptyView()
        case .uploading:
            progressMessage("Uploading EPUB to translator...")
        case .translating:
            if let reconnectMessage = job.errorMessage {
                Label(reconnectMessage, systemImage: "arrow.clockwise")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            } else {
                progressMessage(
                    job.progressText.map {
                        "\(job.activeProgressMessage)... \($0)"
                    } ?? "\(job.activeProgressMessage)..."
                )
            }
        case .importingResult:
            progressMessage("Importing \(job.activeResultName)...")
        case .finished:
            if job.hasFullTranslation {
                Label("Full \(localizedName(for: job.targetLanguage)) translation was added as a separate library book.", systemImage: "checkmark.circle")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            } else {
                Label("\(localizedName(for: job.targetLanguage)) preview was added as a separate library book.", systemImage: "checkmark.circle")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }
        case .failed:
            Label(job.errorMessage ?? "Translation failed.", systemImage: "exclamationmark.triangle")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        }
    }

    private func progressMessage(_ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .tint(palette.accent)
            Text(text)
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsWholeBookOptions.toggle()
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "hammer")
                        .foregroundStyle(palette.accent)
                    Text("Whole book · developer test")
                        .font(Typography.control(16, weight: .medium))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .rotationEffect(.degrees(showsWholeBookOptions ? 180 : 0))
                }
                .frame(minHeight: Spacing.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("translation.fullBookDisclosure")

            if showsWholeBookOptions {
                purchaseOptions
                    .padding(.top, Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
        )
    }

    private var purchaseOptions: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let quote = fullQuote?.quote {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Source characters")
                        Spacer()
                        Text(quote.sourceCharacters.formatted())
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Exact quote")
                        Spacer()
                        Text("\(quote.requiredCredits) credits")
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Available")
                        Spacer()
                        Text("\(creditState?.account.balance ?? 0) credits")
                            .monospacedDigit()
                    }
                }
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)

                if hasEnoughCredits(for: quote) {
                    Button {
                        guard let fullQuote else { return }
                        beginTranslation(
                            kind: .full, preparedUpload: fullQuote
                        )
                    } label: {
                        Label(fullBookButtonTitle, systemImage: "book.closed")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                    .disabled(isRequestingTranslation || job.isBackendActive)
                    .accessibilityIdentifier("translation.fullBook")
                } else if let product = placeholderProduct(for: quote) {
                    Button {
                        addPlaceholderCredits(product)
                    } label: {
                        Label(
                            "Add \(product.credits) test credits · $0",
                            systemImage: "cart.badge.plus"
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                    .disabled(isRequestingTranslation)
                    .accessibilityIdentifier("translation.placeholderPurchase")
                }
            } else {
                Button {
                    prepareFullQuote()
                } label: {
                    Label("Calculate exact quote", systemImage: "number")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                .disabled(
                    !hasAcceptedTerms
                        || !hasBackendIdentity
                        || isRequestingTranslation
                        || job.isBackendActive
                        || job.hasFullTranslation
                        || !book.isTranslatableSource
                )
                .accessibilityIdentifier("translation.calculateQuote")
            }

            if let pricingError {
                Label(pricingError, systemImage: "exclamationmark.triangle")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }

        }
    }

    private var fullBookButtonTitle: LocalizedStringKey {
        job.hasFullTranslation ? "Full translation already added" : "Translate whole book"
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(text)
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            Rectangle()
                .fill(palette.hairline)
                .frame(height: Spacing.hairlineWidth)
        }
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
                if kind == .full {
                    fullQuote = nil
                    creditState = try? await client.credits()
                }
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
                creditState = try await client.credits()
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

    private func addPlaceholderCredits(
        _ product: TranslationBackendClient.CreditProduct
    ) {
        guard let client = backendClient else { return }
        pricingError = nil
        isRequestingTranslation = true
        Task {
            do {
                let response = try await client.grantPlaceholderCredits(
                    transactionID: "debug-\(UUID().uuidString)",
                    productID: product.productId
                )
                creditState = TranslationBackendClient.CreditsResponse(
                    account: response.account,
                    products: creditState?.products ?? []
                )
            } catch {
                pricingError = error.localizedDescription
            }
            isRequestingTranslation = false
        }
    }

    private func hasEnoughCredits(
        for quote: TranslationBackendClient.UploadResponse.Quote
    ) -> Bool {
        (creditState?.account.balance ?? 0) >= quote.requiredCredits
    }

    private func placeholderProduct(
        for quote: TranslationBackendClient.UploadResponse.Quote
    ) -> TranslationBackendClient.CreditProduct? {
        let missing = max(
            0, quote.requiredCredits - (creditState?.account.balance ?? 0)
        )
        let products = (creditState?.products ?? []).sorted {
            $0.credits < $1.credits
        }
        return products.first(where: { $0.credits >= missing })
            ?? products.last
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
    let title: String
    let attestation: String
    let termsLink: String
    let accepted: String
    let notAccepted: String

    static let english = TranslationClickwrapCopy(
        title: "Your book, your rights",
        attestation: "I confirm that I lawfully acquired this book and have the necessary permission or another lawful basis to translate it. I will use the translation only for my own personal, non-commercial reading and will not publish, distribute, sell, or share it. I accept the Terms of Use (22 July 2026).",
        termsLink: "Read the Terms of Use",
        accepted: "Accepted",
        notAccepted: "Not accepted"
    )

    static let hungarian = TranslationClickwrapCopy(
        title: "Saját könyv, saját jogosultság",
        attestation: "Kijelentem, hogy a könyvet jogszerűen szereztem be, és rendelkezem a fordításhoz szükséges engedéllyel vagy más jogalappal. A fordítást kizárólag saját, személyes, nem kereskedelmi olvasásra használom; nem teszem közzé, nem terjesztem, nem adom el és nem osztom meg. Elfogadom a Felhasználási feltételeket (2026. július 22.).",
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

    var activeProgressMessage: String {
        switch activeRequestKind {
        case .full:
            return "Translating whole book on the backend"
        case .preview, nil:
            return "Translating preview on the backend"
        }
    }

    var activeResultName: String {
        switch activeRequestKind {
        case .full:
            return "full translation"
        case .preview, nil:
            return "preview"
        }
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
