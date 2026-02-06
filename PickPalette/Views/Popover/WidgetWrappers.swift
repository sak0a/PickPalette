import SwiftUI

// MARK: - Color Swatch Widget

/// Standalone color swatch circle extracted from the old headerRow.
struct WidgetColorSwatch: View {
    @Bindable var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 52, height: 52)

            Circle()
                .fill(appState.currentColor.color)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .strokeBorder(
                            colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.12),
                            lineWidth: 1
                        )
                )
        }
        .shadow(color: appState.currentColor.color.opacity(0.3), radius: 6, y: 2)
    }
}

// MARK: - Color Space Tabs Widget

/// Standalone color space segmented control extracted from the old headerRow.
struct WidgetColorSpaceTabs: View {
    @Bindable var appState: AppState

    var body: some View {
        GlassSegmentedControl(
            selection: $appState.activeColorSpace,
            options: appState.enabledColorSpaces.map { ($0, $0.displayName) }
        )
    }
}

// MARK: - Hex Field Widget

/// Standalone hex input field extracted from the old headerRow.
/// Owns its own @State and @FocusState for editing behavior.
struct WidgetHexField: View {
    @Bindable var appState: AppState

    @State private var hexFieldText: String = ""
    @State private var isEditingHex: Bool = false
    @FocusState private var hexFieldFocused: Bool
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "number")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField("FFFFFF", text: $hexFieldText, onEditingChanged: { editing in
                isEditingHex = editing
            }, onCommit: {
                if let color = ColorModel.fromHex(hexFieldText) {
                    appState.currentColor = color
                } else {
                    hexFieldText = appState.currentColor.hexString
                }
                isEditingHex = false
            })
            .focused($hexFieldFocused)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(useGlassStyle
                    ? AnyShapeStyle(.ultraThinMaterial)
                    : AnyShapeStyle(colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.93))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
        .onChange(of: appState.currentColor) { _, _ in
            if !hexFieldFocused {
                hexFieldText = appState.currentColor.hexString
            }
        }
        .onAppear {
            hexFieldText = appState.currentColor.hexString
        }
    }
}
