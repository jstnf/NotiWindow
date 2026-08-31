import NotiWindow
import SwiftUI

/// How long toasts stay, and every way one can leave.
struct LifetimeScreen: View {
    let center: NotiCenter

    @State private var syncToken: NotiToken?

    /// Read from the center so the button reflects what is actually on screen.
    private var isSyncing: Bool {
        guard let syncToken else { return false }
        return center.isPresented(syncToken)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Lifetime") {
                    // The label asks the center rather than trusting the local token,
                    // because this toast can leave without the button's help: tapped,
                    // swiped, expired, or replaced by anything else presenting on the
                    // top edge. Holding a token proves it was presented once, not that
                    // it is still there.
                    Button(isSyncing ? "Stop indefinite toast" : "Start indefinite toast") {
                        if let token = syncToken, center.isPresented(token) {
                            center.dismiss(token)
                            syncToken = nil
                        } else {
                            syncToken = center.present(.top, duration: .indefinite) {
                                NotiToast("Syncing…", systemImage: "arrow.triangle.2.circlepath", tint: .blue)
                            }
                        }
                    }

                    Button("Undismissable for 3 seconds") {
                        center.present(.bottom, dismissOnTap: false, dismissOnSwipe: false) {
                            NotiToast("Tap and swipe are disabled", systemImage: "hand.raised.fill", tint: .orange)
                        }
                    }
                }

                Section("Manual dismissal") {
                    Button("Fill both edges for 30s") {
                        center.present(.top, duration: .seconds(30)) {
                            NotiToast("Top — dismiss me by edge", systemImage: "arrow.up.circle.fill", tint: .blue)
                        }
                        center.present(.bottom, duration: .seconds(30)) {
                            NotiToast("Bottom — survives a top-edge dismiss", systemImage: "arrow.down.circle.fill", tint: .purple)
                        }
                    }

                    Button("Dismiss the top toast") {
                        center.dismiss(.top)
                    }

                    Button("Dismiss everything") {
                        center.dismissAll()
                    }
                }
            }
            .navigationTitle("Lifetime")
        }
    }
}
