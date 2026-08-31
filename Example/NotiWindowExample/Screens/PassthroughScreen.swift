import NotiWindow
import SwiftUI

/// Touch handling, sheets, and window resizes — the behaviours that are only visible
/// where a toast overlaps something else.
///
/// **This tab deliberately does not call `.notiClearance()`.** Toasts presented here
/// sit at the true bottom edge, over the tab bar, which is what the library did
/// everywhere before clearance existed. Present one here and one from the Placement
/// tab to see both.
struct PassthroughScreen: View {
    let center: NotiCenter

    @State private var isSheetPresented = false
    @State private var typedText = ""

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                // Raising the keyboard shrinks the safe area, and with it the toast
                // window's container size — so every stored rect stops matching and
                // each toast has to re-report at the new size before it can absorb
                // touches again. That makes this the most common real-world trigger
                // of the resize path, far more so than rotation.
                //
                // Deliberately near the top of the list: the keyboard never covers it,
                // so SwiftUI never scrolls it into view. A scroll would move every
                // other row and invalidate coordinates measured mid-check.
                Section("Keyboard") {
                    TextField("Focus me — the keyboard resizes the window", text: $typedText)
                        .focused($isFieldFocused)

                    // Reaches the interesting state in one tap rather than two, so a
                    // driver has a single action to verify instead of a sequence.
                    Button("Present a toast, then focus the field") {
                        center.present(.bottom, duration: .seconds(30)) {
                            NotiToast("I should survive the keyboard", systemImage: "keyboard", tint: .indigo)
                        }
                        isFieldFocused = true
                    }

                    Button("Dismiss the keyboard") {
                        isFieldFocused = false
                    }
                }

                Section {
                    Button("Present, then tap this row") {
                        center.present(.top, duration: .seconds(30)) {
                            NotiToast("Rows below must still respond", systemImage: "hand.tap.fill", tint: .teal)
                        }
                    }

                    Button("Tap me while a toast is up") {
                        center.present(.bottom) { NotiToast("Passthrough works") }
                    }
                } header: {
                    Text("Passthrough check")
                } footer: {
                    Text(
                        """
                        No .notiClearance() on this tab, so a bottom toast here sits over the tab \
                        bar — and swallows taps on it for as long as it is up.
                        """
                    )
                }

                Section("The reason this library exists") {
                    Button("Present, then open a sheet") {
                        center.present(.bottom, duration: .seconds(30)) {
                            NotiToast("I should stay visible over the sheet", systemImage: "square.3.layers.3d", tint: .pink)
                        }
                        isSheetPresented = true
                    }
                }
            }
            .navigationTitle("Passthrough")
            .sheet(isPresented: $isSheetPresented) {
                SheetScreen(center: center)
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
