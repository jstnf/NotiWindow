import SwiftUI

/// A styled toast pill, for callers who do not want to build their own.
///
/// Entirely optional — `NotiCenter.present` accepts any view. This exists so simple
/// call sites are one-liners, and it depends on nothing in the windowing core.
public struct NotiToast: View {
    private let text: String
    private let systemImage: String?
    private let tint: Color

    /// - Parameters:
    ///   - text: Already-localized copy. This view performs no string lookup.
    ///   - systemImage: Optional leading SF Symbol.
    ///   - tint: Colors the symbol only; text always uses the primary style.
    public init(_ text: String, systemImage: String? = nil, tint: Color = .primary) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }

            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .notiSurface()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// The toast's background surface: Liquid Glass where the OS has it, the previous
/// material everywhere else.
///
/// Kept as one modifier so the choice lives in exactly one place rather than being
/// spelled out at every call site that wants a toast-shaped surface.
private extension View {
    @ViewBuilder
    func notiSurface() -> some View {
        if #available(iOS 26.0, *) {
            // Concentric corners track the display's own curvature, so a toast
            // sitting near an edge stays visually parallel to it; the minimum keeps
            // the pre-26 look wherever there is no container radius to match.
            glassEffect(.regular, in: .rect(corners: .concentric(minimum: .fixed(12))))
        } else {
            background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        NotiToast("Saved to your list")
        NotiToast("Couldn't save", systemImage: "exclamationmark.circle.fill", tint: .red)
        NotiToast("Syncing…", systemImage: "arrow.triangle.2.circlepath", tint: .blue)
    }
    .padding()
}
