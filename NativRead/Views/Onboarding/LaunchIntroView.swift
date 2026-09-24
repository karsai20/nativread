import SwiftUI

/// Picks up where the system launch screen leaves off — same paper, same
/// book mark in the same place — then lets the mark go, so launch is one
/// continuous screen instead of a cut from a static image to the shelf.
struct LaunchIntroView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLeaving = false

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchMark")
                .scaleEffect(isLeaving && !reduceMotion ? 1.12 : 1)
        }
        // The launch screen centres its image on the whole screen.
        .ignoresSafeArea()
        .opacity(isLeaving ? 0 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 0.35)) { isLeaving = true } completion: { onFinished() }
        }
    }
}
