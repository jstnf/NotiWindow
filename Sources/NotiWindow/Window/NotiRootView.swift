import SwiftUI

extension NamedCoordinateSpace {
    /// The toast window's own space, so a toast can measure the window it is in.
    static var notiRoot: NamedCoordinateSpace { .named("NotiWindow.root") }
}

/// Root of the toast window: two independent edge slots over a transparent backdrop.
///
/// Nothing here is opaque or interactive except a live toast, which is what lets
/// `PassthroughWindow` hand every other touch back to the app.
struct NotiRootView: View {
    let center: NotiCenter
    let frameStore: NotiFrameStore
    let clearance: NotiClearance

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// This window's own safe-area insets.
    ///
    /// The part of the app's published clearance that this window already provides for
    /// itself, and so the part that has to come back off again before a toast is
    /// lifted — an iPhone tab bar publishes 83pt of which 34 is the home indicator
    /// this window is already clear of. Measured here rather than read from
    /// `window.safeAreaInsets` so that both sides of that subtraction come from the
    /// same SwiftUI layout, which is the same reason the container size is measured
    /// here.
    @State private var windowInsets = EdgeInsets()

    var body: some View {
        ZStack {
            slot(.top)
            slot(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Named so each toast can measure the window it landed in during the same
        // layout pass that measures the toast. See `NotiSlotView.body`.
        .coordinateSpace(.notiRoot)
        // The size every toast frame is checked against. Measured here, from the same
        // layout as the toasts themselves, so both sides of that comparison come from
        // SwiftUI rather than one of them coming from the window's own bounds — those
        // differ by the safe-area insets.
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            frameStore.setContainerSize(size)
        }
        // Read from the same proxy as the size above, so a resize that changes both —
        // the keyboard coming up, entering Split View — settles them together.
        .onGeometryChange(for: EdgeInsets.self) { proxy in
            proxy.safeAreaInsets
        } action: { insets in
            windowInsets = insets
        }
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
                NotiSlotView(
                    presentation: presentation,
                    center: center,
                    frameStore: frameStore,
                    clearance: clearance,
                    windowInset: edge == .top ? windowInsets.top : windowInsets.bottom
                )
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
    let frameStore: NotiFrameStore
    let clearance: NotiClearance

    /// The toast window's own safe-area inset on this toast's edge.
    let windowInset: CGFloat

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
            //
            // The window's own size is measured alongside it, and for two reasons.
            // It is what lets the window recognise a rect left over from a size it
            // no longer has. It also forces this to re-report after a resize: the
            // action only runs when the observed value changes, and a resize can
            // leave a toast's global frame untouched — a top-anchored toast while
            // the window grows downward — which would otherwise strand the rect at
            // a size nobody will ever match again.
            .onGeometryChange(for: NotiMeasuredFrame.self) { proxy in
                NotiMeasuredFrame(
                    rect: proxy.frame(in: .global),
                    containerSize: proxy.bounds(of: .notiRoot)?.size ?? .zero
                )
            } action: { frame in
                frameStore.set(frame, for: presentation.token)
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 16)
            // Outside the measurement above, which is what makes the inset safe to
            // raise: the toast is laid out further from its edge, so the rect it
            // reports moves with it, and the space the inset opens up belongs to the
            // app rather than being absorbed over a toast that is not there.
            //
            // A caller cannot do this for itself from inside `presentation.content`.
            // `.offset` and every other render-only transform moves what SwiftUI
            // draws without moving the frame it reports to whoever measures it, so a
            // toast positioned that way ends up drawn clear of the rect this window
            // absorbs — untappable, and absorbing an empty band at its resting
            // position for as long as it is up.
            //
            // The app's own chrome is folded in here rather than at presentation time,
            // so a toast already on screen when a tab bar appears or changes height
            // moves with it instead of keeping the inset it was born with.
            .padding(presentation.edge == .top ? .top : .bottom, resolvedInset)
            .offset(y: dragOffset)
            .onTapGesture {
                guard presentation.dismissOnTap else { return }
                center.dismiss(presentation.token)
            }
            .gesture(dragGesture)
    }

    /// How far from its edge this toast is laid out: the clearance the app published
    /// for that edge, plus the gap the toast was presented with.
    private var resolvedInset: CGFloat {
        clearance.inset(
            for: presentation.edge,
            edgeInset: presentation.edgeInset,
            windowInset: windowInset
        )
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
