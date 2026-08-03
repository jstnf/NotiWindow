import NotiWindow
import SwiftUI

struct DemoScreen: View {
    let center: NotiCenter

    @State private var isSheetPresented = false
    @State private var syncToken: NotiToken?

    /// Read from the center so the button reflects what is actually on screen.
    private var isSyncing: Bool {
        guard let syncToken else { return false }
        return center.isPresented(syncToken)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Placement") {
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
                }

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

                Section("Custom content") {
                    Button("Toast with a working button") {
                        center.present(.bottom, duration: .indefinite) {
                            UndoToast {
                                center.present(.top) { NotiToast("Undone") }
                            }
                        }
                    }

                    // No `Spacer`, so this toast sizes to its content and leaves
                    // visibly empty screen beside it. That empty screen is the only
                    // place a "the absorbed rect is wider than the toast" bug shows.
                    Button("Narrow toast (no spacer)") {
                        center.present(.bottom, duration: .seconds(30)) {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Uploading…")
                            }
                            .padding()
                            .background(.regularMaterial, in: Capsule())
                        }
                    }
                }

                Section("Environment access") {
                    EnvironmentPresentButton()
                }

                Section("The reason this library exists") {
                    Button("Present, then open a sheet") {
                        center.present(.bottom, duration: .seconds(30)) {
                            NotiToast("I should stay visible over the sheet", systemImage: "square.3.layers.3d", tint: .pink)
                        }
                        isSheetPresented = true
                    }
                }

                Section("Passthrough check") {
                    Button("Present, then tap this row") {
                        center.present(.top, duration: .seconds(30)) {
                            NotiToast("Rows below must still respond", systemImage: "hand.tap.fill", tint: .teal)
                        }
                    }

                    Button("Tap me while a toast is up") {
                        center.present(.bottom) { NotiToast("Passthrough works") }
                    }
                }
            }
            .navigationTitle("NotiWindow")
            .sheet(isPresented: $isSheetPresented) {
                SheetScreen(center: center)
            }
        }
    }
}

/// Proves that interactive content inside a toast keeps working.
private struct UndoToast: View {
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text("Removed from list")
                .font(.callout)

            Spacer(minLength: 12)

            Button("Undo", action: onUndo)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Presents through `@Environment(\.notiCenter)` rather than the explicitly-passed
/// reference, exercising the environment path that `.notiWindow(_:)` installs.
/// The value is optional because an `EnvironmentValues` default must be constructible
/// from a nonisolated context, and `NotiCenter.init()` is main-actor isolated.
private struct EnvironmentPresentButton: View {
    @Environment(\.notiCenter) private var environmentCenter

    var body: some View {
        Button("Present via @Environment") {
            environmentCenter?.present(.bottom) {
                NotiToast("Presented through the environment", systemImage: "leaf.fill", tint: .mint)
            }
        }
    }
}

private struct SheetScreen: View {
    let center: NotiCenter

    var body: some View {
        NavigationStack {
            List {
                Text("A toast presented before this sheet opened should be visible on top of it.")

                Button("Present from inside the sheet") {
                    center.present(.bottom) {
                        NotiToast("Presented from the sheet", systemImage: "square.stack.3d.up.fill", tint: .indigo)
                    }
                }
            }
            .navigationTitle("Sheet")
        }
    }
}
