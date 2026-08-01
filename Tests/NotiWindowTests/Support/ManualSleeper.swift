@testable import NotiWindow

/// Sleeper whose suspensions resume only when a test says so.
///
/// Keeps timing tests free of wall-clock waits: a test registers a sleep, asserts
/// nothing has happened yet, then fires it and awaits the resulting work directly.
@MainActor
final class ManualSleeper: NotiSleeper {
    /// Every duration asked for, in request order.
    private(set) var requestedDurations: [Duration] = []

    private var pending: [CheckedContinuation<Void, Never>] = []

    /// How many sleeps are currently suspended.
    var pendingCount: Int { pending.count }

    func sleep(for duration: Duration) async throws {
        requestedDurations.append(duration)
        await withCheckedContinuation { continuation in
            pending.append(continuation)
        }
    }

    /// Resume the oldest suspended sleep, as though its duration had elapsed.
    func fireNext() {
        guard !pending.isEmpty else { return }
        pending.removeFirst().resume()
    }

    /// Suspend until at least `count` sleeps are registered.
    ///
    /// Yields rather than waiting on the clock. Expiry work runs on the main actor,
    /// so yielding is enough to let a just-spawned task reach its `sleep` call.
    ///
    /// Spins on `requestedDurations.count`, not `pending.count`: `pending` shrinks
    /// when `fireNext()` resumes a sleep, so a test that fires before awaiting a
    /// later sleep would spin forever against `pending.count`. `requestedDurations`
    /// only grows, so this terminates for the right reason.
    func awaitSleepRequest(count: Int = 1) async {
        while requestedDurations.count < count {
            await Task.yield()
        }
    }
}
