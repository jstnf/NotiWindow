import SwiftUI

/// App-wide toast presentation.
///
/// Holds at most one toast per edge. The two edges are independent slots, so a top
/// and a bottom toast may be on screen at once; presenting again on an occupied edge
/// replaces its occupant.
///
/// The center owns state and timing. A `.notiWindow(center)` modifier renders
/// whatever the center currently holds, which is why a toast presented before the
/// window installs is not lost. Where each live toast actually is on screen is a
/// window's own business, not the center's — see `NotiFrameStore`.
@MainActor
@Observable
public final class NotiCenter {
    private var slots: [NotiEdge: NotiPresentation] = [:]

    @ObservationIgnored private let sleeper: NotiSleeper

    /// Expiry work, kept per edge so tests can await it. Tasks are never cancelled —
    /// each one re-checks that its own token still occupies the slot before
    /// dismissing, so a stale timer cannot cut short the toast that replaced it.
    @ObservationIgnored private var expiryTasks: [NotiEdge: Task<Void, Never>] = [:]

    /// Creates a center that sleeps on the cooperative pool for its expiry timing.
    public init() {
        sleeper = TaskNotiSleeper()
    }

    init(sleeper: NotiSleeper) {
        self.sleeper = sleeper
    }

    /// The toast currently occupying `edge`, if any.
    func presentation(for edge: NotiEdge) -> NotiPresentation? {
        slots[edge]
    }

    /// The tokens of the toasts currently on screen.
    ///
    /// Read by each window at hit-test time. A dismissed or replaced token drops out
    /// of this the moment its slot is cleared, which is what stops its toast
    /// absorbing touches for the length of its exit transition — the window's stored
    /// rect for that token is simply no longer consulted, and is pruned.
    var liveTokens: Set<NotiToken> {
        Set(slots.values.map(\.token))
    }

    /// Expiry work scheduled for `edge`, if any. Test seam.
    func expiryTask(for edge: NotiEdge) -> Task<Void, Never>? {
        expiryTasks[edge]
    }

    /// Surface `content` at `edge`, replacing whatever occupies that edge.
    ///
    /// The returned token identifies this presentation for later dismissal, which
    /// matters most for `.indefinite` toasts that never dismiss themselves.
    @discardableResult
    public func present(
        _ edge: NotiEdge = .bottom,
        duration: NotiDuration = .standard,
        dismissOnTap: Bool = true,
        dismissOnSwipe: Bool = true,
        @ViewBuilder content: () -> some View
    ) -> NotiToken {
        let presentation = NotiPresentation(
            token: NotiToken(),
            edge: edge,
            content: AnyView(content()),
            duration: duration,
            dismissOnTap: dismissOnTap,
            dismissOnSwipe: dismissOnSwipe
        )
        slots[edge] = presentation
        scheduleExpiry(for: presentation)
        return presentation.token
    }

    /// Whether the presentation identified by `token` is still on screen.
    ///
    /// A toast can leave without its presenter's involvement — it can expire, be
    /// tapped or swiped away, or be replaced by something else presenting on the same
    /// edge. Callers holding a token have no other way to notice any of that, so
    /// state derived from a token going stale is the common bug this answers.
    ///
    /// Reading this inside a SwiftUI view body tracks it: the view updates when the
    /// toast goes away, whatever made it go.
    public func isPresented(_ token: NotiToken) -> Bool {
        slots.values.contains { $0.token == token }
    }

    /// Whether any toast currently occupies `edge`.
    public func isPresented(_ edge: NotiEdge) -> Bool {
        slots[edge] != nil
    }

    /// Clear whatever occupies `edge`.
    public func dismiss(_ edge: NotiEdge) {
        clear(edge)
    }

    /// Clear the presentation identified by `token`.
    ///
    /// No-op if that presentation has already been replaced or dismissed, so a late
    /// dismissal cannot tear down an unrelated toast.
    public func dismiss(_ token: NotiToken) {
        for edge in NotiEdge.allCases where slots[edge]?.token == token {
            clear(edge)
        }
    }

    /// Clear both edges.
    public func dismissAll() {
        for edge in NotiEdge.allCases {
            clear(edge)
        }
    }

    /// Empty one slot.
    ///
    /// Dropping the slot is what stops its toast absorbing touches: each window
    /// consults `liveTokens` before its own stored rects, so a cleared toast stops
    /// being hit-tested immediately rather than for the length of its exit animation.
    /// The expiry task handle goes with it too, so `expiryTask(for:)` doesn't report a
    /// stale handle for a slot that no longer has a toast in it — the (possibly still
    /// running) task itself is left alone; it is a no-op once it fires, since
    /// dismissal is token-checked.
    private func clear(_ edge: NotiEdge) {
        slots[edge] = nil
        expiryTasks[edge] = nil
    }

    /// Schedule auto-dismiss for a fixed-duration presentation.
    ///
    /// `.indefinite` schedules nothing at all, so no task exists to fire later.
    ///
    /// Only the token and edge are captured, never the presentation itself — its
    /// `AnyView` content is not `Sendable` and cannot cross into the task.
    private func scheduleExpiry(for presentation: NotiPresentation) {
        let edge = presentation.edge
        let token = presentation.token

        guard case .seconds(let seconds) = presentation.duration else {
            expiryTasks[edge] = nil
            return
        }

        expiryTasks[edge] = Task { [weak self] in
            guard let self else { return }
            do {
                try await sleeper.sleep(for: .seconds(seconds))
            } catch {
                // Cancellation (or any other failure) means this expiry did not
                // actually elapse. Dismissing here would be backwards — the whole
                // point of cancelling a timer is to *not* dismiss its toast.
                return
            }
            // Dismissal is token-checked, so a timer belonging to a toast that has
            // since been replaced finds nothing to clear.
            dismiss(token)
        }
    }
}
