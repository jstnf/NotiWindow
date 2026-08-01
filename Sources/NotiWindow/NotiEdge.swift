/// The screen edge a toast is anchored to.
///
/// Each edge is an independent single-occupancy slot: a top toast and a bottom
/// toast may be on screen simultaneously, and presenting on one edge never
/// disturbs the other.
public enum NotiEdge: Sendable, Hashable, CaseIterable {
    case top
    case bottom
}
