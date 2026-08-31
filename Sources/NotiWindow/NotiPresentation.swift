import Foundation
import SwiftUI

/// Opaque identity for one presentation.
///
/// Returned by `NotiCenter.present` so an `.indefinite` toast can be dismissed
/// later. Dismissing by token is safe against replacement: if the slot has since
/// been taken by another toast, the dismissal is a no-op rather than tearing down
/// an unrelated toast.
public struct NotiToken: Hashable, Sendable {
    private let id: UUID

    init() {
        id = UUID()
    }
}

/// One toast occupying one edge slot.
///
/// Content is type-erased so `NotiCenter` stays non-generic and can be stored and
/// passed freely. With at most two live toasts the cost is irrelevant.
struct NotiPresentation {
    let token: NotiToken
    let edge: NotiEdge
    let content: AnyView
    let duration: NotiDuration
    let dismissOnTap: Bool
    let dismissOnSwipe: Bool

    /// The gap between the toast and the edge it is anchored to.
    ///
    /// Not the whole distance it ends up from that edge: any clearance the app
    /// published for this edge is added at layout time, so this is the gap above the
    /// chrome rather than above the screen. Resolved there rather than here so a toast
    /// already on screen follows chrome that appears or changes height under it — see
    /// `NotiSlotView.resolvedInset`.
    ///
    /// Applied outside the frame the window absorbs touches against, so a toast lifted
    /// clear of some chrome takes its absorbed rect with it, and the space it opens up
    /// keeps passing through. See `NotiSlotView.body`.
    let edgeInset: CGFloat
}
