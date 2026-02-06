import SwiftUI

/// First-launch overlay explaining the eyedropper hotkey and features.
struct OnboardingOverlay: View {
    @Binding var isPresented: Bool
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)

            Text("Welcome to PickPalette")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                featureRow(
                    icon: "eyedropper",
                    title: "Pick Colors",
                    description: "Use the eyedropper or press \u{2325}\u{21E7}C to pick any color on screen."
                )
                featureRow(
                    icon: "doc.on.doc",
                    title: "Copy Formats",
                    description: "Instantly copy colors as HEX, RGB, HSL, and more."
                )
                featureRow(
                    icon: "clock",
                    title: "Recent Colors",
                    description: "Your picked colors are saved for quick access."
                )
                featureRow(
                    icon: "lock.shield",
                    title: "Accessibility",
                    description: "Grant Accessibility permission for global hotkey support."
                )
            }

            Button("Get Started") {
                isPresented = false
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    PopoverTheme.panelBackground(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    PopoverTheme.subtleStroke(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 24)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
