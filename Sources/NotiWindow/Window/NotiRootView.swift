import SwiftUI

/// Root of the toast window: two independent edge slots over a transparent backdrop.
///
/// Nothing here is opaque or interactive except a live toast, which is what lets
/// `PassthroughWindow` hand every other touch back to the app.
struct NotiRootView: View {
    let center: NotiCenter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            slot(.top)
            slot(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func slot(_ edge: NotiEdge) -> some View {
        ZStack(alignment: edge == .top ? .top : .bottom) {
            // Non-interactive filler so the slot can align its toast without
            // becoming a touch target itself.
            Color.clear
                .allowsHitTesting(false)

            if let presentation = center.presentation(for: edge) {
                NotiSlotView(presentation: presentation, center: center)
                    .transition(transition(for: edge))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.3), value: center.presentation(for: edge)?.token)
    }

    /// Slide from the slot's own edge, degrading to a plain fade under Reduce Motion.
    private func transition(for edge: NotiEdge) -> AnyTransition {
        guard !reduceMotion else { return .opacity }

        return .move(edge: edge == .top ? .top : .bottom).combined(with: .opacity)
    }
}

/// One toast, with its dismissal gestures and layout insets.
struct NotiSlotView: View {
    let presentation: NotiPresentation
    let center: NotiCenter

    /// How far the toast must be dragged toward its own edge to dismiss.
    private static let dismissThreshold: CGFloat = 40

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        presentation.content
            .frame(maxWidth: 500)
            .padding(.horizontal, 16)
            .padding(presentation.edge == .top ? .top : .bottom, 8)
            .offset(y: dragOffset)
            .onTapGesture {
                guard presentation.dismissOnTap else { return }
                center.dismiss(presentation.token)
            }
            .gesture(dragGesture)
    }

    /// Drags toward the toast's own edge track the finger; drags away are ignored.
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard presentation.dismissOnSwipe else { return }
                dragOffset = clamped(value.translation.height)
            }
            .onEnded { _ in
                guard presentation.dismissOnSwipe else { return }

                if abs(dragOffset) > Self.dismissThreshold {
                    center.dismiss(presentation.token)
                } else {
                    withAnimation(.spring(duration: 0.2)) { dragOffset = 0 }
                }
            }
    }

    private func clamped(_ translation: CGFloat) -> CGFloat {
        presentation.edge == .top ? min(0, translation) : max(0, translation)
    }
}
