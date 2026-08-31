import NotiWindow
import SwiftUI

/// What can go inside a toast, and how it is reached.
struct ContentScreen: View {
    let center: NotiCenter

    var body: some View {
        NavigationStack {
            List {
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
            }
            .navigationTitle("Content")
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
private struct EnvironmentPresentButton: View {
    @Environment(\.notiCenter) private var environmentCenter

    var body: some View {
        Button("Present via @Environment") {
            environmentCenter.present(.bottom) {
                NotiToast("Presented through the environment", systemImage: "leaf.fill", tint: .mint)
            }
        }
    }
}
