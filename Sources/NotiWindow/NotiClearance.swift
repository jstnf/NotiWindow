import CoreGraphics
import SwiftUI

/// Identity for one publisher of clearance.
///
/// Contributions are keyed rather than collapsed into a single value because more
/// than one can be live at once — see `NotiClearance`.
struct NotiClearanceID: Hashable {
    private let id = UUID()
}

/// How far each edge of this window is obstructed by the app's own chrome.
///
/// The toast window is a second window in the scene, so it cannot see the app's tab
/// bar: it lays out against its own safe area, which covers the home indicator and
/// nothing else. The app publishes what it knows through `.notiClearance(_:)`, and
/// toasts on an obstructed edge rest above the chrome instead of on top of it.
///
/// One per window, exactly like `NotiFrameStore` and for the same reason: two scenes
/// can be showing different chrome, and an inset measured in one means nothing in the
/// other.
///
/// Contributions are kept separately rather than as one value per edge. Both tabs are
/// alive for the length of a tab switch, and a `TabView` keeps visited tabs around
/// after they go away, so a single slot would let whichever view published last decide
/// — including a view that is no longer on screen. Publishing the largest live
/// contribution instead keeps a toast clear of the chrome throughout the switch, and
/// the outgoing tab's inset leaves with it.
@MainActor
@Observable
final class NotiClearance {
    private(set) var contributions: [NotiClearanceID: [NotiEdge: CGFloat]] = [:]

    /// Record what `id` measured, for the edges it declared.
    ///
    /// Edges the caller did not declare are left out rather than stored as zero.
    /// Nothing today can tell the two apart, since `published(for:)` takes a maximum
    /// and a missing edge already reads as zero — but a stored zero would have the
    /// store claiming a measurement the view never declared, which is the kind of
    /// thing a later rule reads and gets wrong.
    func set(_ insets: EdgeInsets, edges: Set<NotiEdge>, for id: NotiClearanceID) {
        var measured: [NotiEdge: CGFloat] = [:]

        for edge in edges {
            measured[edge] = edge == .top ? insets.top : insets.bottom
        }

        contributions[id] = measured
    }

    /// Drop `id`'s contribution, as its publisher goes off screen.
    func remove(_ id: NotiClearanceID) {
        contributions[id] = nil
    }

    /// The largest inset any live contribution measured for `edge`.
    func published(for edge: NotiEdge) -> CGFloat {
        contributions.values.compactMap { $0[edge] }.max() ?? 0
    }

    /// The padding a toast on `edge` should be laid out with.
    ///
    /// `windowInset` is the toast window's own safe-area inset on that edge, which the
    /// root view measures for itself — see `NotiRootView`.
    func inset(for edge: NotiEdge, edgeInset: CGFloat, windowInset: CGFloat) -> CGFloat {
        Self.resolvedInset(edgeInset: edgeInset, published: published(for: edge), windowInset: windowInset)
    }

    /// Stack the caller's own inset on top of the clearance the app published.
    ///
    /// The published inset is measured from the window edge, and the toast window is
    /// already laid out inside its own safe area, so the two overlap: an iPhone tab bar
    /// publishes 83pt of which the window itself already provides 34. Subtracting gives
    /// the part that is actually chrome, and clamping at zero means a view that
    /// publishes *less* than the window's own inset — anything laid out outside the
    /// safe area — can never pull a toast down towards its edge.
    ///
    /// The two are added rather than reconciled, which is what keeps each of them
    /// meaning one thing. Clearance moves where the edge effectively *is*; `edgeInset`
    /// is the gap from that edge, exactly as it is with no clearance published. So the
    /// default 8pt is the same 8pt of breathing room whether a toast is resting on the
    /// tab bar or on the bottom of the screen, and an inset a caller passes always
    /// moves the toast — under `max` an inset smaller than the clearance did nothing at
    /// all, silently.
    ///
    /// The cost is that the two compose, so a caller already passing `edgeInset:` to
    /// clear chrome by hand will double up once that chrome is published. Publishing
    /// clearance is what replaces those hand-written insets; delete them.
    nonisolated static func resolvedInset(edgeInset: CGFloat, published: CGFloat, windowInset: CGFloat) -> CGFloat {
        max(0, published - windowInset) + edgeInset
    }
}
