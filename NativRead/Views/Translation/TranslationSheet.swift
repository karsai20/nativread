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
    @Environment(PricingStore.self) private var pricing
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasAcceptedTerms = false
    @State private var isRequestingTranslation = false
    @State private var detectedLanguage: DetectedBookLanguage = .unknown
    @State private var usesLocalTestAccount = false
    @State private var fullQuote: TranslationBackendClient.UploadResponse?
    @State private var bookProduct: Product?
    @State private var isEntitledToFullBook = false
    @State private var pricingError: String?
    @State private var pendingAITranslation: PendingAITranslation?
    @State private var showsTermsOfUse = false
    /// Fraction of the book sent so far, or `nil` when no upload is running.
    @State private var uploadProgress: Double?
    /// StoreKit products for every price band, keyed by identifier.
    @State private var bandProducts: [String: Product] = [:]
    /// The book's own character count, resolved once when the sheet opens.
    /// Held here rather than read from `book` because a book shelved before
    /// counts existed is counted on the spot, and `book` is this sheet's own
    /// copy — it would not see the number the library just wrote down.
    @State private var sourceCharacters: Int?
    /// Sign in with Apple comes forward only once the reader reaches for an
    /// action — the page leads with the book and its price, not a login.
    @State private var showsSignIn = false

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var progressLabels: TranslationProgressLabels {
        TranslationProgressLabels(job: job, uploadProgress: uploadProgress, locale: locale)
    }

    private var job: TranslationJob {
        translations.job(for: book)
    }

    /// A store's book page: title and author, the two ways in (the whole
    /// book, or its first chapter free) side by side, then the facts a
    /// reader weighs in one strip. The cover above it lives in
    /// `TranslationStage`.
    var body: some View {
        VStack(spacing: 0) {
            if let statusKicker {
                Text(statusKicker)
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.note)
                    .padding(.bottom, Spacing.xs)
                    .accessibilityIdentifier("translation.kicker")
            }

            Text(book.title)
                .font(.custom(Typography.displayFamily, size: 30))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: book.author)
                .font(Typography.meta(14))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
                .padding(.top, Spacing.xxs)

            TranslationLanguagePicker(
                choices: targetChoices,
                selected: job.targetLanguage,
                isSelectedApproved: isTargetApproved,
                isEnabled: !job.phase.isInFlight && !job.hasFullTranslation,
                palette: palette,
                onSelect: { translations.setTargetLanguage($0, for: book) }
            )
            .padding(.top, Spacing.lg)

            actionArea
                .padding(.top, Spacing.md)
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showsAccount)

            TranslationFactsStrip(
                chapters: String.localizedStringWithFormat(
                    String(localized: "%lld chapters", bundle: .appLanguage, locale: locale),
                    max(1, book.spineWeights.count)
                ),
                readingTime: readingHours.map {
                    String.localizedStringWithFormat(
                        String(localized: "%lld h", bundle: .appLanguage, locale: locale), $0
                    )
                } ?? "–",
                original: sourceLanguageName,
                readyIn: readyInText ?? "–",
                palette: palette
            )
            .padding(.top, Spacing.lg)

            TranslationFinePrint(palette: palette, onTerms: { showsTermsOfUse = true })
                .padding(.top, Spacing.md)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("translation.hero")
        .sheet(isPresented: $showsTermsOfUse) {
            NavigationStack { TermsOfUseView() }
        }
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
            keepTargetOnOffer()
        }
        .onChange(of: targetChoices) { _, _ in keepTargetOnOffer() }
        .task {
            // Awaited: pricing the book needs the table, and reading it before
            // the fetch lands is what put "See price" on a card that could
            // already have shown the price.
            await pricing.refreshIfStale()
            await resolvePriceWithoutUpload()
            await loadBandProducts()
        }
    }

    // MARK: - Flap sections

    /// State word above the title, only once there is a state to name.
    private var statusKicker: LocalizedStringKey? {
        switch job.phase {
        case .draft, .attested:
            return job.hasFullTranslation ? "On your shelf" : nil
        case .uploading, .translating, .importingResult, .finished, .failed:
            return progressLabels.headline
        }
    }

    /// The detected source language's code, nil until trusted.
    private var sourceLanguageCode: String? {
        guard case .language(let code, _, _) = detectedLanguage, detectedLanguage.isTrusted else {
            return nil
        }
        return String(code.prefix(2)).lowercased()
    }

    /// "Angol" in a Hungarian app; "–" until the upload detects it.
    private var sourceLanguageName: String {
        guard let code = sourceLanguageCode else { return "–" }
        return (locale.localizedString(forLanguageCode: code) ?? code.uppercased()).capitalized
    }

    /// What the backend will translate this book into, never its own
    /// language. Read from the price table, so closing a testing pair on the
    /// server takes it out of the picker.
    private var targetChoices: [TranslationTargetLanguage] {
        if let table = pricing.pricing {
            return table.targetLanguages(from: sourceLanguageCode)
        }
        return TranslationTargetLanguage.passed.filter { $0.rawValue != sourceLanguageCode }
    }

    private var isTargetApproved: Bool {
        pricing.pricing?.isApproved(from: sourceLanguageCode, to: job.targetLanguage)
            ?? TranslationTargetLanguage.passed.contains(job.targetLanguage)
    }

    /// Keeps the chosen language one the page offers: a Hungarian book
    /// defaults to English, and a pair the server closed falls back.
    private func keepTargetOnOffer() {
        let choices = targetChoices
        guard !choices.contains(job.targetLanguage),
              !job.phase.isInFlight, !job.hasFullTranslation,
              let fallback = choices.contains(.en) ? .en : choices.first
        else { return }
        translations.setTargetLanguage(fallback, for: book)
    }

    /// Source characters the flap knows about — the library's count, or the
    /// book's own if it was shelved with one.
    private var knownSourceCharacters: Int? {
        sourceCharacters ?? book.sourceCharacters
    }

    // ponytail: 68k characters per reading hour (≈200 wpm), 200k characters
    // per translator minute (PLAN.md measured ~12 min for a 2.4M book).
    private static let charactersPerReadingHour = 68_000.0
    private static let charactersPerTranslatorMinute = 200_000.0

    private var readingHours: Int? {
        guard let characters = knownSourceCharacters, characters > 0 else { return nil }
        return max(1, Int((Double(characters) / Self.charactersPerReadingHour).rounded()))
    }

    private var readyInText: String? {
        guard let characters = knownSourceCharacters, characters > 0 else { return nil }
        let minutes = max(3, Int((Double(characters) / Self.charactersPerTranslatorMinute).rounded()))
        return "~" + String.localizedStringWithFormat(String(localized: "%lld min", bundle: .appLanguage, locale: locale), minutes)
    }

    // MARK: - Actions

    /// The sign-in, once asked for; otherwise the book's two ways in.
    private var showsAccount: Bool {
        showsSignIn && !hasBackendIdentity && !job.isBackendActive && !job.hasFullTranslation
    }

    @ViewBuilder
    private var actionArea: some View {
        VStack(spacing: Spacing.sm) {
            if showsAccount {
                TranslationAccountSection(palette: palette) {
                    usesLocalTestAccount = true
                    pricingError = nil
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                VStack(spacing: Spacing.xs) {
                    primaryAction
                    if !job.isBackendActive && !job.hasFullTranslation {
                        TranslationSampleButton(
                            isOnShelf: job.hasFreePreview,
                            isEnabled: !job.hasFreePreview && (!hasBackendIdentity || canStartRequest),
                            palette: palette,
                            action: startFreeChapter
                        )
                    }
                }
                .transition(.opacity)
            }

            if exceedsLongestTier {
                Text("This book is longer than we can translate.")
                    .font(Typography.meta())
                    .foregroundStyle(palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("translation.tooLong")
            }

            if let pricingError {
                Text(verbatim: pricingError)
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if job.phase == .failed, let message = job.errorMessage {
                Text(verbatim: message)
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if job.phase == .translating, let reconnect = job.errorMessage {
                Text(verbatim: reconnect)
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Before an account exists the capsule still shows the verb and, when
    /// StoreKit already knows it, the price; tapping it asks for the sign-in.
    @ViewBuilder
    private var primaryAction: some View {
        if !hasBackendIdentity && !job.isBackendActive && !job.hasFullTranslation {
            TranslateCapsule(
                title: String(localized: "Translate", bundle: .appLanguage),
                price: bookProduct?.displayPrice,
                progress: nil,
                isEnabled: book.isTranslatableSource && !exceedsLongestTier,
                palette: palette,
                action: { showsSignIn = true }
            )
            .accessibilityIdentifier("translation.start")
        } else {
            capsule
        }
    }

    /// The whole-book action, one capsule whose label follows the flow: no
    /// price yet → get one, price → buy, paid → translate, running → the
    /// capsule fills chapter by chapter, done → the state.
    @ViewBuilder
    private var capsule: some View {
        if job.isBackendActive {
            TranslateCapsule(
                title: progressLabels.capsuleTitle,
                price: nil,
                progress: progressLabels.capsuleProgress,
                isEnabled: false,
                palette: palette,
                action: {}
            )
            .accessibilityIdentifier("translation.progress")
        } else if job.hasFullTranslation {
            TranslateCapsule(
                title: String(localized: "Added to your shelf", bundle: .appLanguage),
                price: nil, progress: 1, isEnabled: false, palette: palette, action: {}
            )
            .accessibilityIdentifier("translation.fullBook")
        } else if isEntitledToFullBook || (fullQuote != nil && fullQuote?.price == nil) {
            TranslateCapsule(
                title: String(localized: "Translate", bundle: .appLanguage),
                price: nil,
                progress: nil,
                isEnabled: !isRequestingTranslation && book.isTranslatableSource,
                palette: palette,
                action: {
                    guard let fullQuote else { return }
                    acceptTermsIfNeeded()
                    beginTranslation(kind: .full, preparedUpload: fullQuote)
                }
            )
            .accessibilityIdentifier("translation.fullBook")
        } else if let bookProduct {
            // The price always comes from StoreKit, never from our own tier
            // table: it is the only source that is localized and matches what
            // the App Store will actually charge.
            TranslateCapsule(
                title: String(localized: "Translate", bundle: .appLanguage),
                price: bookProduct.displayPrice,
                progress: nil,
                isEnabled: canStartRequest && !purchases.isPurchasing,
                palette: palette,
                action: {
                    acceptTermsIfNeeded()
                    buyFullBook(bookProduct)
                }
            )
            .accessibilityIdentifier("translation.purchaseFullBook")
        } else {
            TranslateCapsule(
                title: String(localized: isRequestingTranslation ? "Getting the price…" : "Get the price", bundle: .appLanguage),
                price: nil,
                progress: uploadProgress,
                isEnabled: canStartRequest && !exceedsLongestTier,
                palette: palette,
                action: {
                    acceptTermsIfNeeded()
                    prepareFullQuote()
                }
            )
            .accessibilityIdentifier("translation.calculateQuote")
        }
    }

    private func startFreeChapter() {
        guard hasBackendIdentity else {
            showsSignIn = true
            return
        }
        acceptTermsIfNeeded()
        beginTranslation(kind: .preview)
    }

    /// The button is the acceptance: the fine print beside it says what the
    /// tap confirms, and the record carries the same locale and version the
    /// checkbox used to write.
    private func acceptTermsIfNeeded() {
        guard !hasAcceptedTerms else { return }
        translations.recordTermsAcceptance(for: book, localeIdentifier: locale.identifier)
        hasAcceptedTerms = true
    }

    /// The gate every plan shares: an account, nothing already running, and a
    /// source file the backend can actually take. Terms are accepted by the
    /// tap itself (`acceptTermsIfNeeded`), so they are not a precondition of
    /// the button being live.
    private var canStartRequest: Bool {
        hasBackendIdentity
            && !isRequestingTranslation
            && !job.isBackendActive
            && book.isTranslatableSource
    }

    private func requestTranslation(
        kind: TranslationRequestKind,
        preparedUpload: TranslationBackendClient.UploadResponse? = nil
    ) {
        guard kind == .full || !job.hasFreePreview else { return }
        guard kind == .preview || !job.hasFullTranslation else { return }
        // Acceptance is recorded by the tap that got us here
        // (`acceptTermsIfNeeded`); never set it anywhere else.
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

    /// Puts a price on screen without sending the book anywhere, so the reader
    /// decides on a number instead of on a progress bar.
    ///
    /// Two sources, in order of authority: the price the backend quoted for
    /// these exact bytes last time, then the tier this build counts the book
    /// into itself. Both are display only — the upload inside `buyFullBook`
    /// re-derives the tier server-side before anything is charged.
    ///
    /// Entitlement is deliberately *not* restored from either: a book bought on
    /// another device would otherwise still look unowned here, and the reader
    /// could be charged for it twice. Ownership is always read from the upload
    /// that has to happen before a purchase anyway.
    private func resolvePriceWithoutUpload() async {
        guard book.format == .epub, fullQuote == nil, bookProduct == nil else {
            return
        }
        if let productId = await cachedQuotedProductID() {
            bookProduct = try? await purchases.product(for: productId)
            return
        }
        guard let productId = locallyPricedProductID() else { return }
        bookProduct = try? await purchases.product(for: productId)
    }

    /// Prices for every band. One StoreKit round trip for the whole table, and
    /// it is what makes the bands appear at the same time as the book's own
    /// price rather than after a second wait.
    private func loadBandProducts() async {
        guard let table = pricing.usablePricing, bandProducts.isEmpty else {
            return
        }
        let loaded = await purchases.products(for: table.productIDs)
        bandProducts = Dictionary(
            uniqueKeysWithValues: loaded.map { ($0.id, $0) }
        )
    }

    /// The product the backend named for this file, if the file still is the
    /// one it was quoted for.
    private func cachedQuotedProductID() async -> String? {
        guard let cachedHash = book.quotedSourceHash,
              let productId = book.quotedProductId
        else { return nil }
        let sourceURL = library.storedFileURL(for: book)
        let currentHash = await Task.detached(priority: .utility) {
            LibraryStore.sourceHash(ofFileAt: sourceURL)
        }.value
        // A different file under the same book is a different quote.
        return currentHash == cachedHash ? productId : nil
    }

    /// The product this build's own character count puts the book in, or nil
    /// when there is nothing trustworthy to price with — no table fetched yet,
    /// a table published for counting rules this build does not implement, or a
    /// book too long to be sold at all.
    private func locallyPricedProductID() -> String? {
        // Counting a book shelved before counts existed writes to the library,
        // so it happens here — inside a task — and never while a body is being
        // evaluated.
        sourceCharacters = library.sourceCharacters(for: book)
        guard let table = pricing.usablePricing,
              let characters = sourceCharacters
        else { return nil }
        return table.tier(forSourceCharacters: characters)?.productId
    }

    /// True when the book is longer than the backend sells, which is worth
    /// saying before the reader waits through an upload that ends in a refusal.
    private var exceedsLongestTier: Bool {
        guard let table = pricing.usablePricing,
              let characters = sourceCharacters ?? book.sourceCharacters
        else { return false }
        return table.exceedsLongestTier(sourceCharacters: characters)
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

    /// The product the server's own count says this book is sold as.
    ///
    /// Normally the one already on screen: the on-device counter is a port of
    /// the server's, pinned character-for-character by `QuoteGoldenTests`. When
    /// they do disagree the reader is shown the real price and asked again
    /// rather than being charged an amount the button never displayed — one
    /// extra tap, in a case that should not happen.
    private func confirmedProduct(
        for upload: TranslationBackendClient.UploadResponse,
        shown: Product
    ) async throws -> Product {
        guard let serverProductID = upload.price?.productId,
              serverProductID != shown.id
        else { return shown }
        let corrected = try await purchases.product(for: serverProductID)
        bookProduct = corrected
        pricingError = String(
            localized: "This book's price is \(corrected.displayPrice). Tap again to buy it."
        )
        return corrected
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
                // The upload just produced the server's own character count,
                // and that is the only tier `POST /api/purchase` will accept.
                // If the price on screen came from this device's count and
                // lands in a different tier, charging for `product` would take
                // the reader's money and then be refused.
                let confirmed = try await confirmedProduct(
                    for: upload, shown: product
                )
                guard confirmed.id == product.id else { return }
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
        if usesLocalTestAccount && settings.isPrivateTestTranslationBackend {
            return TranslationBackendClient(
                baseURL: backendURL, userID: settings.translationUserID
            )
        }
#endif
        return nil
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

private struct PendingAITranslation: Identifiable {
    let id = UUID()
    let kind: TranslationRequestKind
    let preparedUpload: TranslationBackendClient.UploadResponse?
}
