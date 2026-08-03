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
                // Keying on the token gives each presentation its own view identity,
                // so a same-edge replacement reads as a removal plus an insertion
                // rather than an update to the existing view. That is what replays
                // the transition and gives the incoming toast a fresh `dragOffset`,
                // instead of inheriting the outgoing toast's drag state.
                NotiSlotView(presentation: presentation, center: center)
                    .id(presentation.token)
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
            // Makes the whole toast tappable, not just the parts of it that draw
            // something. SwiftUI does not hit-test empty stack space, and a
            // background style adds no hit region of its own — so a toast whose
            // content ends in a `Spacer` to fill the width (which `NotiToast` does)
            // only receives touches over its text and symbol.
            //
            // Without this the window still absorbs the full measured rect while
            // SwiftUI delivers nothing, so the empty part of every toast is dead: it
            // will not dismiss, and it will not fall through to the app either.
            // Applied here, to the same view the frame is measured from, so the
            // region that can be interacted with is exactly the region the window
            // absorbs.
            .contentShape(Rectangle())
            // The window absorbs touches by frame, so the toast has to say where it
            // landed. Nothing else in this window knows: SwiftUI draws the toast
            // inside the hosting view rather than in a `UIView` the window could
            // hit-test against.
            //
            // Measured here, on the content itself, rather than around the padding
            // and the `maxWidth` frame below — those make a full-width row, and a
            // toast that does not fill it would otherwise absorb touches over
            // visibly empty screen beside it.
            //
            // `.global` already reflects the `.offset` below, so the absorbed rect
            // follows a live drag rather than sitting at the resting position.
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                center.setContentFrame(frame, forToken: presentation.token)
            }
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
