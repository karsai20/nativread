import SwiftUI
import PDFKit

/// Book-like fixed-layout PDF surface: single page, horizontal swipe
/// paging and tap zones for page turns. PDFKit supplies its native text
/// selection menu, including Apple's Look Up dictionary action.
struct PDFKitView: UIViewRepresentable {
    let documentURL: URL
    let pageIndex: Int
    let isNight: Bool
    let backgroundColor: UIColor
    let onPageChange: (Int) -> Void
    let onTapZone: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.usePageViewController(true)
        view.autoScales = true
        view.backgroundColor = backgroundColor
        context.coordinator.pdfView = view
        context.coordinator.loadDocument(isNight: isNight, restoringPage: pageIndex)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged, object: view
        )
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        view.backgroundColor = backgroundColor

        if context.coordinator.isNight != isNight {
            // Night toggling swaps the page render class, so the document
            // is rebuilt (PDFDocument is lazy — cheap) and the page restored.
            context.coordinator.loadDocument(
                isNight: isNight, restoringPage: context.coordinator.currentIndex
            )
        } else if context.coordinator.currentIndex != pageIndex {
            // External page change (scrubber, TOC, search, tap zone).
            context.coordinator.go(toIndex: pageIndex)
        }
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    @MainActor
    final class Coordinator: NSObject, PDFDocumentDelegate,
                             UIGestureRecognizerDelegate {
        var parent: PDFKitView
        weak var pdfView: PDFView?
        /// Read by PDFKit's `classForPage()` on a background thread during
        /// page instantiation, written on the main actor. A stale read at
        /// worst renders one page in the old mode, corrected on next layout
        /// — so a plain unsynchronised flag is safe here.
        nonisolated(unsafe) private var nightFlag = false
        var isNight: Bool { nightFlag }
        /// The display surface's own document copy, so a rebuild never
        /// touches the view model's metadata/search document.
        private var displayDocument: PDFDocument?

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        var currentIndex: Int {
            guard let page = pdfView?.currentPage,
                  let document = displayDocument else { return 0 }
            return document.index(for: page)
        }

        /// (Re)builds the display document with the right page class for the
        /// current night setting and restores the reader to `restoringPage`.
        func loadDocument(isNight: Bool, restoringPage: Int) {
            nightFlag = isNight
            guard let pdfView,
                  let document = PDFDocument(url: parent.documentURL) else { return }
            document.delegate = self
            displayDocument = document
            pdfView.document = document
            go(toIndex: restoringPage)
        }

        func go(toIndex index: Int) {
            guard let pdfView, let document = displayDocument else { return }
            let clamped = min(max(index, 0), document.pageCount - 1)
            guard clamped >= 0, let page = document.page(at: clamped) else { return }
            pdfView.go(to: page)
        }

        // MARK: PDFDocumentDelegate

        /// PDFKit asks per page which class to instantiate; the inverting
        /// subclass renders night mode, the base class renders normally.
        nonisolated func classForPage() -> AnyClass {
            nightFlag ? NightInvertPDFPage.self : PDFPage.self
        }

        // MARK: Events

        @objc func pageChanged() {
            parent.onPageChange(currentIndex)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView else { return }
            // A tap first dismisses an active selection rather than turning.
            if pdfView.currentSelection != nil {
                pdfView.clearSelection()
                return
            }
            let x = gesture.location(in: pdfView).x
            let width = pdfView.bounds.width
            if x < width * 0.3 {
                parent.onTapZone("left")
            } else if x > width * 0.7 {
                parent.onTapZone("right")
            } else {
                parent.onTapZone("center")
            }
        }

        nonisolated func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
}
