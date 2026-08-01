/// How long a toast holds before dismissing itself.
public enum NotiDuration: Sendable, Hashable {
    /// Hold for a fixed interval, then dismiss.
    case seconds(Double)

    /// Never auto-dismiss. The caller is responsible for dismissing, using the
    /// token returned by `NotiCenter.present`.
    case indefinite

    /// The default hold for a transient toast.
    public static let standard: NotiDuration = .seconds(3)
}
