import AuthenticationServices
import OSLog
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
    /// A price lookup the reader asked to retry is running.
    @State private var isResolvingPrice = false
    @State private var detectedLanguage: DetectedBookLanguage = .unknown
    @State private var usesLocalTestAccount = false
    @State private var fullQuote: TranslationBackendClient.UploadResponse?
    @State private var bookProduct: Product?
    /// Languages this account already owns the book in, from the backend.
    @State private var ownedLanguages: Set<String> = []
    @State private var isPaying = false
    @State private var showsAIConsentDetails = false
    @State private var pricingError: String?
    @State private var showsTermsOfUse = false
    /// Fraction of the book sent so far, or `nil` when no upload is running.
    @State private var uploadProgress: Double?
    /// StoreKit products for every price band, keyed by identifier.
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
                isApproved: isApproved,
                isEnabled: !job.phase.isInFlight && !job.hasFullTranslation,
                palette: palette,
                onSelect: { translations.setTargetLanguage($0, for: book) }
            )
            .padding(.top, Spacing.lg)

            actionArea
                .padding(.top, Spacing.md)
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showsAccount)

            TranslationFactsGrid(
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
        .sheet(isPresented: $showsAIConsentDetails) {
            AIProcessingConsentView(providerName: TranslationPrivacy.aiProviderName) {
                translations.recordAIProcessingConsent(for: book)
                showsAIConsentDetails = false
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
            await refreshOwnership()
        }
        .onChange(of: auth.isSignedIn) { _, _ in Task { await refreshOwnership() } }
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

    private func isApproved(_ target: TranslationTargetLanguage) -> Bool {
        pricing.pricing?.isApproved(from: sourceLanguageCode, to: target)
            ?? TranslationTargetLanguage.passed.contains(target)
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

    /// The AI provider may translate: asked on the page, once for every book,
    /// before anything can be sent (App Review 5.1.2(i)).
    private var hasAIConsent: Bool { translations.hasAIProcessingConsent }

    private var offersActions: Bool { !job.isBackendActive && !job.hasFullTranslation }

    @ViewBuilder
    private var actionArea: some View {
        VStack(spacing: Spacing.sm) {
            if offersActions {
                TranslationAIConsentRow(
                    isOn: Binding(
                        get: { hasAIConsent },
                        set: { allowed in
                            if allowed {
                                translations.recordAIProcessingConsent(for: book)
                            } else {
                                translations.clearAIProcessingConsents()
                            }
                        }
                    ),
                    providerName: TranslationPrivacy.aiProviderDisplayName,
                    palette: palette,
                    onDetails: { showsAIConsentDetails = true }
                )
            }
            if showsAccount {
                if let price = bookProduct?.displayPrice {
                    Text(String(localized: "Full book · \(price)", bundle: .appLanguage))
                        .font(Typography.control(15, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .accessibilityIdentifier("translation.price")
                }
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
                            isEnabled: hasAIConsent && !job.hasFreePreview && (!hasBackendIdentity || canStartRequest),
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
                isEnabled: hasAIConsent && book.isTranslatableSource && !exceedsLongestTier,
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
                title: String(localized: isPaying ? "Processing…" : "Translate", bundle: .appLanguage),
                price: isPaying ? nil : bookProduct.displayPrice,
                progress: nil,
                isEnabled: hasAIConsent && canStartRequest && !isPaying,
                palette: palette,
                action: {
                    acceptTermsIfNeeded()
                    payThenTranslate(bookProduct)
                }
            )
            .accessibilityIdentifier("translation.purchaseFullBook")
        } else if settings.isPrivateTestTranslationBackend {
            // A local translator sells nothing: quoting through an upload is how
            // a debug run reaches the translate button.
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
        } else {
            // The price is only ever worked out on this device. When that
            // fails (no table, StoreKit unreachable) the reader retries; the
            // book is never uploaded just to learn what it costs.
            TranslateCapsule(
                title: String(localized: isResolvingPrice ? "Getting the price…" : "Price unavailable. Try again", bundle: .appLanguage),
                price: nil,
                progress: nil,
                isEnabled: !isResolvingPrice && !exceedsLongestTier && book.isTranslatableSource,
                palette: palette,
                action: retryPrice
            )
            .accessibilityIdentifier("translation.retryPrice")
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

        let run = TranslationRun(
            client: client,
            book: book,
            kind: kind,
            sourceURL: sourceURL,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            termsAcceptance: termsAcceptance,
            translations: translations,
            library: library
        )
        Task {
            do {
                try await run.perform(preparedUpload: preparedUpload)
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
        // Permission is given once, on the page; each book it is used for
        // carries its own record of it.
        guard translations.hasAIProcessingConsent else { return }
        if job.acceptedAIProcessingVersion != TranslationPrivacy.currentAIConsentVersion {
            translations.recordAIProcessingConsent(for: book)
        }
        requestTranslation(kind: kind, preparedUpload: preparedUpload)
    }

    /// Puts a price on screen without sending the book anywhere, so the reader
    /// decides on a number instead of on a progress bar.
    ///
    /// Two sources, in order of authority: the price the backend quoted for
    /// these exact bytes last time, then the tier this build counts the book
    /// into itself. This is the tier the reader pays for; the server checks it
    /// against its own count when the translation starts.
    ///
    /// Entitlement is deliberately *not* restored from either: ownership comes
    /// from the backend by hash (`refreshOwnership`, and again right before
    /// paying), so a book bought on another device is never charged twice.
    private func resolvePriceWithoutUpload() async {
        guard book.format == .epub, fullQuote == nil, bookProduct == nil else {
            return
        }
        if let productId = await cachedQuotedProductID() {
            await loadProduct(productId)
            return
        }
        guard let productId = locallyPricedProductID() else { return }
        await loadProduct(productId)
    }

    /// StoreKit's answer for the book's tier. A failure is said, not hidden:
    /// the usual cause is a product App Store Connect does not (yet) serve.
    private func loadProduct(_ productId: String) async {
        do {
            bookProduct = try await purchases.product(for: productId)
            pricingError = nil
        } catch {
            Self.log.error("StoreKit product \(productId, privacy: .public) unavailable: \(error.localizedDescription, privacy: .public)")
            pricingError = error.localizedDescription
        }
    }

    private static let log = Logger(subsystem: "com.karsai.nativread", category: "translation-pricing")

    private func retryPrice() {
        isResolvingPrice = true
        Task {
            await pricing.refreshIfStale()
            await resolvePriceWithoutUpload()
            isResolvingPrice = false
        }
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

    /// Quotes the book through an upload. Only a local debug translator, which
    /// sells nothing, still takes this path; a paid book is never uploaded
    /// before the purchase.
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
            ownedLanguages = Set(upload.entitledLanguages ?? [])
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

    private var isEntitledToFullBook: Bool {
        ownedLanguages.contains(job.targetLanguage.rawValue)
    }

    /// The book's content hash, which names it to the backend without the
    /// book itself. Worked out off the main thread; the file can be large.
    private func sourceHash() async -> String? {
        let sourceURL = library.storedFileURL(for: book)
        return await Task.detached(priority: .userInitiated) {
            LibraryStore.sourceHash(ofFileAt: sourceURL)
        }.value
    }

    /// Asks the backend, by hash, which languages this reader already owns
    /// the book in, so a book bought on another device shows as owned.
    private func refreshOwnership() async {
        guard book.format == .epub, auth.isSignedIn, let client = backendClient,
              let hash = await sourceHash(),
              let owned = try? await client.entitledLanguages(sourceHash: hash)
        else { return }
        ownedLanguages = Set(owned)
    }

    /// Pays for the book by its hash, then uploads it. Nothing leaves the
    /// device before the purchase is confirmed by the backend — and a reader
    /// who already owns this language is not charged again.
    private func payThenTranslate(_ product: Product) {
        guard let appAccountToken = auth.appAccountToken, let client = backendClient else { return }
        let targetLanguage = job.targetLanguage.rawValue
        isPaying = true
        pricingError = nil
        Task {
            defer { isPaying = false }
            do {
                guard let hash = await sourceHash() else {
                    pricingError = String(localized: "This book's file could not be read.", bundle: .appLanguage)
                    return
                }
                await purchases.confirmUnfinishedTransactions()
                let owned = try await client.entitledLanguages(sourceHash: hash)
                if !owned.contains(targetLanguage) {
                    let target = PurchaseTarget.book(
                        sourceHash: hash, targetLanguage: targetLanguage, productID: product.id
                    )
                    switch try await purchases.purchase(product, for: target, appAccountToken: appAccountToken) {
                    case .entitled:
                        break
                    case .cancelled:
                        return
                    case .pending:
                        pricingError = String(localized: "This purchase needs approval. The translation starts once it is approved.", bundle: .appLanguage)
                        return
                    }
                }
                ownedLanguages.insert(targetLanguage)
                beginTranslation(kind: .full)
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
