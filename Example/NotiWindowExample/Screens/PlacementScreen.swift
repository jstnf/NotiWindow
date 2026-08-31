import NotiWindow
import SwiftUI

/// Where toasts land: the two edges, replacement, and clearing the tab bar.
///
/// This tab publishes clearance (see `NotiWindowExampleApp`), so every toast presented
/// from here rests above the tab bar rather than on top of it. `PassthroughScreen`
/// deliberately does not, which is what makes the difference visible in one tap.
struct PlacementScreen: View {
    let center: NotiCenter

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Bottom toast") {
                        center.present(.bottom) {
                            NotiToast("Saved to your list", systemImage: "checkmark.circle.fill", tint: .green)
                        }
                    }

                    Button("Top toast") {
                        center.present(.top) {
                            NotiToast("Connection restored", systemImage: "wifi", tint: .blue)
                        }
                    }

                    Button("Both at once") {
                        center.present(.top) {
                            NotiToast("Top", systemImage: "arrow.up", tint: .blue)
                        }
                        center.present(.bottom) {
                            NotiToast("Bottom", systemImage: "arrow.down", tint: .purple)
                        }
                    }

                    Button("Replace the bottom toast") {
                        center.present(.bottom) { NotiToast("First") }
                        center.present(.bottom) { NotiToast("Second replaced it") }
                    }
                } header: {
                    Text("Placement")
                } footer: {
                    Text(
                        """
                        This tab calls .notiClearance(), so bottom toasts rest above the tab bar \
                        rather than on top of it. The Passthrough tab does not — present a toast \
                        there to compare. On iPad, where the tab bar is at the top and SwiftUI \
                        draws it, there is nothing to measure: a top toast overlaps it, and the \
                        bottom edge is free.
                        """
                    )
                }

                Section {
                    // Asking for no gap at all is the one way to land flush on the tab
                    // bar: the clearance still lifts it, and nothing is added on top.
                    Button("No inset — flush on the tab bar") {
                        center.present(.bottom, duration: .seconds(30), edgeInset: 0) {
                            NotiToast("Resting on the tab bar", systemImage: "arrow.up.to.line", tint: .teal)
                        }
                    }

                    // Every inset moves the toast, including a small one: this is the
                    // default 8pt row lifted a further 16pt.
                    Button("24pt above the tab bar") {
                        center.present(.bottom, duration: .seconds(30), edgeInset: 24) {
                            NotiToast("24pt of gap", systemImage: "arrow.up.and.line.horizontal.and.arrow.down", tint: .gray)
                        }
                    }

                    // The gap is measured from the chrome, not from the window edge, so
                    // this lands 200pt above the tab bar rather than 200pt up the screen.
                    Button("200pt above the tab bar") {
                        center.present(.bottom, duration: .seconds(30), edgeInset: 200) {
                            NotiToast("200pt of gap", systemImage: "arrow.up.to.line", tint: .indigo)
                        }
                    }

                    // Tap the toast where it draws: an inset toast is interactive at
                    // its lifted position, and the band it left behind still scrolls
                    // the list underneath.
                    Button("Tappable where it draws") {
                        center.present(.bottom, duration: .seconds(30), edgeInset: 108) {
                            NotiToast("Tap me, then tap where I'm not", systemImage: "hand.tap.fill", tint: .pink)
                        }
                    }
                } header: {
                    Text("Insets and clearance")
                } footer: {
                    Text(
                        """
                        Clearance moves where the edge is; edgeInset is the gap from it. The two \
                        add up, so every inset moves the toast — and the default 8pt is the same \
                        gap here as it is with no tab bar to clear.
                        """
                    )
                }
            }
            .navigationTitle("Placement")
        }
    }
}
