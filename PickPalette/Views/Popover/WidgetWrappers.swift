import SwiftUI

// MARK: - Color Swatch Widget

/// Standalone color swatch that respects the user's chosen shape and size.
/// Scales down to fit when the container is smaller than the natural content height.
struct WidgetColorSwatch: View {
    @Bindable var appState: AppState
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    private var naturalContentHeight: CGFloat {
        appState.swatchSize.outerSize + 6 + 18
    }

    var body: some View {
        GeometryReader { geo in
            let scale = min(1.0, geo.size.height / max(naturalContentHeight, 1))
            VStack(spacing: 6) {
                swatchView
                swatchControls
            }
            .scaleEffect(scale, anchor: .center)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    // MARK: - Swatch Shape View

    @ViewBuilder
    private var swatchView: some View {
        let shape = appState.swatchShape
        let size  = appState.swatchSize
        let bg    = PopoverTheme.controlBackground(useGlassStyle: useGlassStyle, colorScheme: colorScheme)
        let stroke: Color = colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.12)

        ZStack {
            switch shape {
            case .circle:
                Circle()
                    .fill(bg)
                    .frame(width: size.outerSize, height: size.outerSize)
                Circle()
                    .fill(appState.currentColor.color)
                    .frame(width: size.innerSize, height: size.innerSize)
                    .overlay(Circle().strokeBorder(stroke, lineWidth: 1))

            case .roundedRect:
                RoundedRectangle(cornerRadius: size.cornerRadius + 2)
                    .fill(bg)
                    .frame(width: size.outerSize, height: size.outerSize)
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(appState.currentColor.color)
                    .frame(width: size.innerSize, height: size.innerSize)
                    .overlay(RoundedRectangle(cornerRadius: size.cornerRadius).strokeBorder(stroke, lineWidth: 1))

            case .square:
                Rectangle()
                    .fill(bg)
                    .frame(width: size.outerSize, height: size.outerSize)
                Rectangle()
                    .fill(appState.currentColor.color)
                    .frame(width: size.innerSize, height: size.innerSize)
                    .overlay(Rectangle().strokeBorder(stroke, lineWidth: 1))
            }
        }
        .shadow(color: appState.currentColor.color.opacity(0.3), radius: 6, y: 2)
    }

    // MARK: - Shape & Size Pickers

    private var swatchControls: some View {
        HStack(spacing: 6) {
            // Shape picker
            HStack(spacing: 2) {
                ForEach(SwatchShape.allCases, id: \.self) { shape in
                    let isActive = appState.swatchShape == shape
                    Button {
                        appState.swatchShape = shape
                        appState.save()
                    } label: {
                        Image(systemName: shape.icon)
                            .font(.system(size: 9, weight: isActive ? .bold : .regular))
                            .foregroundStyle(isActive ? Color.accentColor : .secondary)
                            .frame(width: 18, height: 18)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(shape.displayName)
                }
            }

            Divider().frame(height: 12)

            // Size picker
            HStack(spacing: 2) {
                ForEach(SwatchSize.allCases, id: \.self) { size in
                    let isActive = appState.swatchSize == size
                    Button {
                        appState.swatchSize = size
                        appState.save()
                    } label: {
                        Text(size.displayName)
                            .font(.system(size: 9, weight: isActive ? .bold : .medium))
                            .foregroundStyle(isActive ? Color.accentColor : .secondary)
                            .frame(width: 18, height: 18)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(size.displayName)
                }
            }
        }
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
                .fill(
                    PopoverTheme.controlBackground(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    )
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
