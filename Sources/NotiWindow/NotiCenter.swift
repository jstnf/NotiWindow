import SwiftUI

/// App-wide toast presentation.
///
/// Holds at most one toast per edge. The two edges are independent slots, so a top
/// and a bottom toast may be on screen at once; presenting again on an occupied edge
/// replaces its occupant.
///
/// The center owns state and timing but knows nothing about windows. A
/// `.notiWindow(center)` modifier renders whatever the center currently holds, which
/// is why a toast presented before the window installs is not lost.
@MainActor
@Observable
public final class NotiCenter {
    private var slots: [NotiEdge: NotiPresentation] = [:]

    @ObservationIgnored private let sleeper: NotiSleeper

    /// Expiry work, kept per edge so tests can await it. Tasks are never cancelled —
    /// each one re-checks that its own token still occupies the slot before
    /// dismissing, so a stale timer cannot cut short the toast that replaced it.
    @ObservationIgnored private var expiryTasks: [NotiEdge: Task<Void, Never>] = [:]

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

    /// Clear whatever occupies `edge`.
    public func dismiss(_ edge: NotiEdge) {
        slots[edge] = nil
    }

    /// Clear the presentation identified by `token`.
    ///
    /// No-op if that presentation has already been replaced or dismissed, so a late
    /// dismissal cannot tear down an unrelated toast.
    public func dismiss(_ token: NotiToken) {
        for edge in NotiEdge.allCases where slots[edge]?.token == token {
            slots[edge] = nil
        }
    }

    /// Clear both edges.
    public func dismissAll() {
        slots.removeAll()
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
            try? await sleeper.sleep(for: .seconds(seconds))
            // Dismissal is token-checked, so a timer belonging to a toast that has
            // since been replaced finds nothing to clear.
            dismiss(token)
        }
    }
}
