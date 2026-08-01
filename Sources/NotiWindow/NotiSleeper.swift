/// Timing seam for auto-dismiss.
///
/// Isolated to the main actor because every call site already is — `NotiCenter` is
/// `@MainActor`, and its expiry tasks inherit that isolation. Isolating the protocol
/// lets test doubles hold plain mutable state.
@MainActor
protocol NotiSleeper {
    func sleep(for duration: Duration) async throws
}

/// Production sleeper. Suspends without blocking the main actor.
struct TaskNotiSleeper: NotiSleeper {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
