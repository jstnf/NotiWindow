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
}
