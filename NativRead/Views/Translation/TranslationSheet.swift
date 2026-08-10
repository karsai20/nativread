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
    @State private var selectedPlan: TranslationPlan = .freeChapter
    @State private var pendingAITranslation: PendingAITranslation?
    @State private var showsTermsOfUse = false
    /// Fraction of the book sent so far, or `nil` when no upload is running.
    @State private var uploadProgress: Double?

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var job: TranslationJob {
        translations.job(for: book)
    }

    private var clickwrapCopy: TranslationClickwrapCopy {
        locale.language.languageCode?.identifier == "hu" ? .hungarian : .english
    }

    /// The attestation with its inline Terms link. Falls back to plain text
    /// if the markdown ever fails to parse, so the sentence is never lost.
    private var attestationText: AttributedString {
        (try? AttributedString(markdown: clickwrapCopy.attestation))
            ?? AttributedString(clickwrapCopy.attestation)
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
                        if showsPhaseMessage { progressCard }
                        planPicker
                        actionSection
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
                from: library.languageDetectionSample(for: book),
                declared: library.declaredLanguage(for: book)
            )
            // The sample is only worth offering once; a reader who already has
            // it lands on the option they can still act on.
            if job.hasFreePreview && !job.hasFullTranslation {
                selectedPlan = .wholeBook
            }
        }
        .task { await restoreCachedPrice() }
    }

    /// The book being translated, shown the way the shelf shows it: cover,
    /// title, author, and the direction the translation runs in.
    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            BookCard.cover(book: book, coverURL: library.coverURL(for: book))
                .frame(width: 62, height: 93)
                .clipShape(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 4)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(book.title)
                    .font(Typography.display(24))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.author)
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)

                AppPill(title: languagePairText, palette: palette)
                    .padding(.top, Spacing.xxs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("translation.hero")
    }

    /// The two things on sale, both on screen from the first frame: the free
    /// sample and the whole book. One card is selected at a time and the sheet's
    /// single primary button follows the selection.
    private var planPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            AppSectionLabel(title: "Choose what to translate", palette: palette)

            TranslationPlanCard(
                plan: .freeChapter,
                title: "First chapter",
                subtitle: "See the quality before you decide.",
                badge: job.hasFreePreview
                    ? String(localized: "Added") : String(localized: "Free"),
                isSelected: selectedPlan == .freeChapter,
                isEnabled: !job.isBackendActive,
                palette: palette,
                action: { select(.freeChapter) }
            )
            .accessibilityIdentifier("translation.plan.freeChapter")

            TranslationPlanCard(
                plan: .wholeBook,
                title: "Whole book",
                subtitle: "Every chapter. One purchase, yours for good.",
                badge: wholeBookBadge,
                isRecommended: !job.hasFullTranslation,
                isSelected: selectedPlan == .wholeBook,
                isEnabled: !job.isBackendActive,
                palette: palette,
                action: { select(.wholeBook) }
            )
            .accessibilityIdentifier("translation.plan.wholeBook")
        }
    }

    /// Price on the trailing edge of the whole-book card. StoreKit is the only
    /// source of a real price, so anything else is a state, not a number.
    private var wholeBookBadge: String {
        if job.hasFullTranslation { return String(localized: "Added") }
        if isEntitledToFullBook || (fullQuote != nil && fullQuote?.price == nil) {
            return String(localized: "Owned")
        }
        if let bookProduct { return bookProduct.displayPrice }
        return String(localized: "See price")
    }

    private func select(_ plan: TranslationPlan) {
        withAnimation(.easeInOut(duration: 0.18)) { selectedPlan = plan }
    }

    /// "English → Magyar", or just the target when detection came up empty.
    ///
    /// A low-confidence guess is shown as nothing rather than as a language:
    /// `requestCode` already discards it, so naming it here would put a source
    /// on screen that the translation is not actually going to use.
    private var languagePairText: String {
        let target = localizedName(for: job.targetLanguage)
        guard case .language(let code, let fallbackName, _) = detectedLanguage,
              detectedLanguage.isTrusted
        else { return "→ \(target)" }
        let source = (locale.localizedString(forLanguageCode: code)
            ?? fallbackName).capitalized
        return "\(source) → \(target)"
    }

    /// One line: a checkbox and the attestation, whose "Terms of Use" is the
    /// link itself — no second row repeating the same destination.
    private var termsAcceptanceSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
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
                Image(
                    systemName: hasAcceptedTerms
                        ? "checkmark.square.fill" : "square"
                )
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: Spacing.minTapTarget, height: Spacing.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("translation.termsAcceptance")
            .accessibilityLabel(Text(String(attestationText.characters)))
            .accessibilityAddTraits(hasAcceptedTerms ? [.isSelected] : [])
            .accessibilityValue(
                hasAcceptedTerms ? clickwrapCopy.accepted : clickwrapCopy.notAccepted
            )

            Text(attestationText)
                .font(Typography.body(16))
                .foregroundStyle(palette.text)
                .tint(palette.accent)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("translation.terms.link")
        }
        // The link is a URL, not a NavigationLink, so the tap is caught here
        // and turned into the same push the old row made.
        .environment(\.openURL, OpenURLAction { _ in
            showsTermsOfUse = true
            return .handled
        })
        .navigationDestination(isPresented: $showsTermsOfUse) {
            TermsOfUseView()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusSmall, style: .continuous)
        )
    }

    /// Everything the reader has to pass through before the selected plan can
    /// start: the rights attestation, an account, then the one button.
    private var actionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if !job.isBackendActive && !job.hasFullTranslation {
                termsAcceptanceSection
            }

            if !job.isBackendActive && hasAcceptedTerms && !hasBackendIdentity {
                accountSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            primaryAction

            // The whole book goes over the wire here, which on a phone
            // connection is the slowest thing this screen does. A disabled
            // button alone reads as a hang.
            if let uploadProgress {
                ProgressView(value: uploadProgress) {
                    Text(
                        uploadProgress < 1
                            ? "Uploading \(Int(uploadProgress * 100))%…"
                            : "Measuring the book…"
                    )
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
                }
                .tint(palette.accent)
                .accessibilityIdentifier("translation.uploadProgress")
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

            Text(footnote)
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeInOut(duration: 0.22), value: hasAcceptedTerms)
    }

    private var footnote: LocalizedStringKey {
        switch selectedPlan {
        case .freeChapter:
            return "The translation arrives as a separate book on your shelf. Your original stays unchanged."
        case .wholeBook:
            return "One purchase per book. Buy it once and it stays yours — reinstall the app and it comes back."
        }
    }

    /// One dominant button, whose job is decided by the selected plan and by how
    /// far the whole-book flow has got (no price yet → quote, price → buy,
    /// already paid → translate).
    @ViewBuilder
    private var primaryAction: some View {
        switch selectedPlan {
        case .freeChapter:
            AppPrimaryButton(
                title: freePreviewButtonTitle,
                systemImage: "sparkles",
                isEnabled: canStartRequest && !job.hasFreePreview,
                action: { beginTranslation(kind: .preview) },
                palette: palette
            )
            .accessibilityIdentifier("translation.freeChapter")
        case .wholeBook:
            wholeBookAction
        }
    }

    @ViewBuilder
    private var wholeBookAction: some View {
        // `bookProduct` alone is enough: a cached price restores it without an
        // upload, so the reader sees the cost straight away and the book only
        // goes over the wire once they decide to buy.
        //
        // No price *on a real upload response* means the backend is not selling
        // this book — a self-hosted deployment with entitlements turned off.
        // Nothing to buy, so the translation is simply available. A missing
        // `fullQuote` means the price came from the cache instead, which is not
        // the same thing.
        if isEntitledToFullBook || (fullQuote != nil && fullQuote?.price == nil) {
            AppPrimaryButton(
                title: fullBookButtonTitle,
                systemImage: "book.closed",
                isEnabled: !isRequestingTranslation
                    && !job.isBackendActive
                    && !job.hasFullTranslation,
                action: {
                    guard let fullQuote else { return }
                    beginTranslation(kind: .full, preparedUpload: fullQuote)
                },
                palette: palette
            )
            .accessibilityIdentifier("translation.fullBook")
        } else if let bookProduct {
            // The price always comes from StoreKit, never from our own tier
            // table: it is the only source that is localized and matches what
            // the App Store will actually charge.
            AppPrimaryButton(
                title: "Translate whole book · \(bookProduct.displayPrice)",
                systemImage: "cart",
                isEnabled: canStartRequest
                    && !job.hasFullTranslation
                    && !purchases.isPurchasing,
                action: { buyFullBook(bookProduct) },
                palette: palette
            )
            .accessibilityIdentifier("translation.purchaseFullBook")
        } else {
            AppPrimaryButton(
                title: "Calculate exact quote",
                systemImage: "number",
                isEnabled: canStartRequest && !job.hasFullTranslation,
                action: { prepareFullQuote() },
                palette: palette
            )
            .accessibilityIdentifier("translation.calculateQuote")
        }
    }

    /// The gate every plan shares: accepted terms, an account, nothing already
    /// running, and a source file the backend can actually take.
    private var canStartRequest: Bool {
        hasAcceptedTerms
            && hasBackendIdentity
            && !isRequestingTranslation
            && !job.isBackendActive
            && book.isTranslatableSource
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
        let sourceLanguage = detectedLanguage.requestCode
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
                        sourceLanguage: sourceLanguage,
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

    /// Shows the price the backend quoted for this exact file last time,
    /// without sending the book anywhere.
    ///
    /// Display only. Entitlement is deliberately *not* restored from the cache:
    /// a book bought on another device would otherwise still look unowned here,
    /// and the reader could be charged for it twice. Ownership is always read
    /// from the upload that has to happen before a purchase anyway.
    private func restoreCachedPrice() async {
        guard book.format == .epub,
              fullQuote == nil, bookProduct == nil,
              let cachedHash = book.quotedSourceHash,
              let productId = book.quotedProductId
        else { return }
        let sourceURL = library.storedFileURL(for: book)
        let currentHash = await Task.detached(priority: .utility) {
            LibraryStore.sourceHash(ofFileAt: sourceURL)
        }.value
        // A different file under the same book is a different quote.
        guard currentHash == cachedHash else { return }
        bookProduct = try? await purchases.product(for: productId)
    }

    /// The upload this flow cannot skip: StoreKit binds a purchase to a backend
    /// job id, and a job id only exists once the book is on the server. Both
    /// the explicit quote and the first tap on a cached price come through here.
    private func uploadForQuote(
        client: TranslationBackendClient
    ) async throws -> TranslationBackendClient.UploadResponse {
        translations.markBackendUploadStarted(for: book, kind: .full)
        let sourceURL = library.storedFileURL(for: book)
        let progress = $uploadProgress
        uploadProgress = 0
        defer { uploadProgress = nil }

        do {
            let upload = try await client.upload(epubURL: sourceURL) { fraction in
                Task { @MainActor in progress.wrappedValue = fraction }
            }
            guard upload.quote != nil else {
                throw TranslationBackendClient.ClientError.invalidResponse
            }
            fullQuote = upload
            isEntitledToFullBook = upload.entitledLanguages?.contains("hu") ?? false
            // Remember the price against the bytes it was quoted for, so
            // reopening this sheet costs nothing.
            if let hash = upload.sourceHash, let price = upload.price {
                library.recordQuote(
                    bookID: book.id, sourceHash: hash, productId: price.productId
                )
            }
            translations.markBackendQuoteReady(for: book, backendJobID: upload.id)
            return upload
        } catch {
            // This function is what moved the job into `.uploading`, so it is
            // what has to move it out. A job left uploading is reloaded from
            // disk as an interrupted one on the next launch.
            translations.markBackendFailed(
                for: book, message: error.localizedDescription
            )
            throw error
        }
    }

    private func prepareFullQuote() {
        guard hasAcceptedTerms, let client = backendClient else { return }
        guard book.format == .epub else { return }
        pricingError = nil
        isRequestingTranslation = true

        Task {
            do {
                let upload = try await uploadForQuote(client: client)
                if !isEntitledToFullBook, let price = upload.price {
                    // Not `try?`. The book has already gone over the wire and
                    // the reader is waiting for a number; a product StoreKit
                    // will not load leaves `bookProduct` nil, which renders as
                    // the untouched "Calculate exact quote" button — an upload
                    // that silently undoes itself, with no price and no reason.
                    bookProduct = try await purchases.product(for: price.productId)
                }
            } catch {
                pricingError = error.localizedDescription
            }
            isRequestingTranslation = false
        }
    }

    private func buyFullBook(_ product: Product) {
        guard let appAccountToken = auth.appAccountToken else { return }
        pricingError = nil
        Task {
            do {
                // A cached price got us here without an upload, so the book has
                // to go up now — and its response, not the cache, decides
                // whether this reader already owns the translation.
                let upload: TranslationBackendClient.UploadResponse
                if let fullQuote {
                    upload = fullQuote
                } else {
                    guard hasAcceptedTerms, let client = backendClient else { return }
                    isRequestingTranslation = true
                    do {
                        upload = try await uploadForQuote(client: client)
                    } catch {
                        isRequestingTranslation = false
                        throw error
                    }
                    isRequestingTranslation = false
                }
                // Either the reader already owns this book, or the backend is
                // not selling it at all. Both mean there is nothing to charge
                // for, and the cached price must not talk us into StoreKit.
                guard !isEntitledToFullBook, upload.price != nil else {
                    beginTranslation(kind: .full, preparedUpload: upload)
                    return
                }
                switch try await purchases.purchase(
                    product,
                    jobID: upload.id,
                    appAccountToken: appAccountToken
                ) {
                case .entitled:
                    isEntitledToFullBook = true
                    beginTranslation(kind: .full, preparedUpload: upload)
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
    /// The rights statement has to be made **on screen**, not only inside the
    /// Terms: the acceptance record sent to the backend carries
    /// `statementVersion`, and an App Review 5.2 pass rests on the reviewer
    /// seeing the attestation in the flow (`docs/legal-posture.md` MUST-FIX #1).
    /// Markdown: the link target is never opened as a URL — the sheet
    /// intercepts it and pushes the Terms instead.
    let attestation: String
    let accepted: String
    let notAccepted: String

    static let english = TranslationClickwrapCopy(
        attestation: "I own this book and have the right to translate it for my personal use — [Terms of Use](nativread://terms).",
        accepted: "Accepted",
        notAccepted: "Not accepted"
    )

    static let hungarian = TranslationClickwrapCopy(
        attestation: "Sajátom ez a könyv, és jogosult vagyok személyes használatra lefordíttatni — [Felhasználási feltételek](nativread://terms).",
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
