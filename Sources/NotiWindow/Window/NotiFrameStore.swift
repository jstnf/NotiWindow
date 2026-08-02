import CoreGraphics

/// A toast's rect, plus the container size it was measured in.
///
/// The size is the staleness check. Window coordinates only mean something relative
/// to a particular container size, and the rects are written a layout pass behind the
/// window itself — so during a resize they describe geometry that no longer exists.
struct NotiMeasuredFrame: Equatable {
    var rect: CGRect
    var containerSize: CGSize
}

/// Where this window's toasts are, as its own root view last measured them.
///
/// One per window rather than one per center, because a rect in window coordinates
/// only means something to the window it was measured in. That is also what lets a
/// single `NotiCenter` drive several scenes at once: each scene's window keeps its
/// own rects, so two windows showing the same toast no longer overwrite each other.
///
/// Liveness is not kept here. Which toasts are still on screen is the center's
/// business, and asking it at hit-test time is what makes a dismissal stop absorbing
/// touches immediately rather than for the length of its exit transition.
@MainActor
final class NotiFrameStore {
    private(set) var frames: [NotiToken: NotiMeasuredFrame] = [:]

    /// The size of the root view as of its last layout.
    ///
    /// Compared against each frame's own `containerSize` to spot rects left over from
    /// a size the window no longer has. Deliberately the root view's size rather than
    /// the window's `bounds`: the root is laid out inside the safe area, so the two
    /// differ by the insets, and comparing across that boundary would mark every
    /// frame stale forever.
    private(set) var containerSize: CGSize = .zero

    func setContainerSize(_ size: CGSize) {
        containerSize = size
    }

    /// Keyed by token rather than by edge so a toast on its way out cannot overwrite
    /// the rect of the toast that replaced it: both are laying out at once during the
    /// exchange, and they share an edge but never a token.
    func set(_ frame: NotiMeasuredFrame, for token: NotiToken) {
        frames[token] = frame
    }

    /// The rects belonging to `liveTokens`, dropping any measured at a size the root
    /// no longer has. Everything else is unknown geometry, and unknown means fail
    /// open.
    ///
    /// Entries for tokens that are no longer live are pruned here rather than on
    /// dismissal, so nothing has to notify this store when a toast goes away.
    func liveFrames(for liveTokens: Set<NotiToken>) -> [CGRect] {
        frames = frames.filter { liveTokens.contains($0.key) }

        return frames.values.compactMap { frame in
            frame.containerSize == containerSize ? frame.rect : nil
        }
    }
}
