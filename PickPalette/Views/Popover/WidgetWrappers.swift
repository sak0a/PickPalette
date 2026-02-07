import SwiftUI

// MARK: - Color Swatch Widget

/// Standalone color swatch extracted from the old headerRow.
/// Supports circle or squircle shape.
struct WidgetColorSwatch: View {
    @Bindable var appState: AppState
    var size: CGFloat = 52
    var shape: SwatchShape = .circle
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    private var outerDiameter: CGFloat { size }
    private var innerDiameter: CGFloat { size * (44.0 / 52.0) }
    private var scale: CGFloat { size / 52.0 }
    private var outerRadius: CGFloat { size * 0.22 }
    private var innerRadius: CGFloat { innerDiameter * 0.22 }

    var body: some View {
        ZStack {
            switch shape {
            case .circle:
                Circle()
                    .fill(
                        PopoverTheme.controlBackground(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        )
                    )
                    .frame(width: outerDiameter, height: outerDiameter)

                Circle()
                    .fill(appState.currentColor.color)
                    .frame(width: innerDiameter, height: innerDiameter)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.12),
                                lineWidth: max(0.5, scale)
                            )
                    )

            case .squircle:
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .fill(
                        PopoverTheme.controlBackground(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        )
                    )
                    .frame(width: outerDiameter, height: outerDiameter)

                RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                    .fill(appState.currentColor.color)
                    .frame(width: innerDiameter, height: innerDiameter)
                    .overlay(
                        RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                            .strokeBorder(
                                colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.12),
                                lineWidth: max(0.5, scale)
                            )
                    )
            }
        }
        .shadow(color: appState.currentColor.color.opacity(0.3), radius: max(2, 6 * scale), y: max(1, 2 * scale))
    }
}

// MARK: - Color Space Tabs Widget

/// Standalone color space segmented control extracted from the old headerRow.
struct WidgetColorSpaceTabs: View {
    @Bindable var appState: AppState
    var height: CGFloat = 34
    var enabledSpaces: [ColorSpaceGroup]? = nil
    var orientation: Axis = .horizontal

    /// Use per-widget enabled spaces if set, otherwise fall back to app-wide setting.
    private var effectiveSpaces: [ColorSpaceGroup] {
        if let spaces = enabledSpaces, !spaces.isEmpty {
            return spaces
        }
        return appState.enabledColorSpaces
    }

    var body: some View {
        GlassSegmentedControl(
            selection: $appState.activeColorSpace,
            options: effectiveSpaces.map { ($0, $0.displayName) },
            height: height,
            orientation: orientation
        )
    }
}

// MARK: - Hex Field Widget

/// Standalone hex input field extracted from the old headerRow.
/// Owns its own @State and @FocusState for editing behavior.
struct WidgetHexField: View {
    @Bindable var appState: AppState
    var height: CGFloat = 28

    @State private var hexFieldText: String = ""
    @State private var isEditingHex: Bool = false
    @FocusState private var hexFieldFocused: Bool
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    private var scale: CGFloat { height / 28.0 }
    private var iconFont: CGFloat { max(7, 10 * scale) }
    private var textFont: CGFloat { max(9, 13 * scale) }
    private var hPadding: CGFloat { max(4, 8 * scale) }
    private var vPadding: CGFloat { max(2, 4 * scale) }
    private var cornerRadius: CGFloat { max(3, 6 * scale) }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "number")
                .font(.system(size: iconFont, weight: .medium))
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
            .font(.system(size: textFont, weight: .medium, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    PopoverTheme.controlBackground(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
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

// MARK: - Color Space Field Widget

/// Text input field showing the current color in the active color space format.
/// Displays and accepts values like rgb(255, 128, 0), hsl(30, 100%, 50%), etc.
struct WidgetColorSpaceField: View {
    @Bindable var appState: AppState
    var height: CGFloat = 28

    @State private var fieldText: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var fieldFocused: Bool
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    private var scale: CGFloat { height / 28.0 }
    private var labelFont: CGFloat { max(6, 8 * scale) }
    private var textFont: CGFloat { max(9, 13 * scale) }
    private var hPadding: CGFloat { max(4, 8 * scale) }
    private var vPadding: CGFloat { max(2, 4 * scale) }
    private var cornerRadius: CGFloat { max(3, 6 * scale) }

    /// The short label shown as a prefix, e.g. "RGB", "HSL".
    private var spaceLabel: String {
        switch appState.activeColorSpace {
        case .rgb: return "RGB"
        case .hsl: return "HSL"
        case .hsb: return "HSB"
        case .cmyk: return "CMYK"
        default: return "RGB"
        }
    }

    /// Formatted display string for the current color.
    private var displayString: String {
        let c = appState.currentColor
        switch appState.activeColorSpace {
        case .rgb:
            return "rgb(\(Int(round(c.red * 255))), \(Int(round(c.green * 255))), \(Int(round(c.blue * 255))))"
        case .hsl:
            return "hsl(\(Int(round(c.hue * 360))), \(Int(round(c.saturationHSL * 100)))%, \(Int(round(c.lightness * 100)))%)"
        case .hsb:
            return "hsb(\(Int(round(c.hueHSB * 360))), \(Int(round(c.saturationHSB * 100)))%, \(Int(round(c.brightness * 100)))%)"
        case .cmyk:
            return "cmyk(\(Int(round(c.cyan * 100)))%, \(Int(round(c.magenta * 100)))%, \(Int(round(c.yellow * 100)))%, \(Int(round(c.key * 100)))%)"
        default:
            return "rgb(\(Int(round(c.red * 255))), \(Int(round(c.green * 255))), \(Int(round(c.blue * 255))))"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(spaceLabel)
                .font(.system(size: labelFont, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)

            TextField(displayString, text: $fieldText, onEditingChanged: { editing in
                isEditing = editing
            }, onCommit: {
                if let parsed = parseColorString(fieldText) {
                    appState.currentColor = parsed
                }
                fieldText = displayString
                isEditing = false
            })
            .focused($fieldFocused)
            .textFieldStyle(.plain)
            .font(.system(size: textFont, weight: .medium, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    PopoverTheme.controlBackground(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
        .onChange(of: appState.currentColor) { _, _ in
            if !fieldFocused {
                fieldText = displayString
            }
        }
        .onChange(of: appState.activeColorSpace) { _, _ in
            if !fieldFocused {
                fieldText = displayString
            }
        }
        .onAppear {
            fieldText = displayString
        }
    }

    // MARK: - Parsing

    /// Parse a color string like "rgb(255, 128, 0)" or "hsl(30, 100%, 50%)" into a ColorModel.
    private func parseColorString(_ input: String) -> ColorModel? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Try rgb(r, g, b)
        if let values = extractValues(from: trimmed, prefix: "rgb", count: 3) {
            let r = values[0] / 255.0
            let g = values[1] / 255.0
            let b = values[2] / 255.0
            guard r >= 0, r <= 1, g >= 0, g <= 1, b >= 0, b <= 1 else { return nil }
            return ColorModel(red: r, green: g, blue: b, alpha: appState.currentColor.alpha)
        }

        // Try hsl(h, s%, l%)
        if let values = extractValues(from: trimmed, prefix: "hsl", count: 3) {
            let h = values[0] / 360.0
            let s = values[1] / 100.0
            let l = values[2] / 100.0
            guard h >= 0, h <= 1, s >= 0, s <= 1, l >= 0, l <= 1 else { return nil }
            return ColorModel.fromHSL(h: h, s: s, l: l, a: appState.currentColor.alpha)
        }

        // Try hsb(h, s%, b%)
        if let values = extractValues(from: trimmed, prefix: "hsb", count: 3) {
            let h = values[0] / 360.0
            let s = values[1] / 100.0
            let b = values[2] / 100.0
            guard h >= 0, h <= 1, s >= 0, s <= 1, b >= 0, b <= 1 else { return nil }
            return ColorModel.fromHSB(h: h, s: s, b: b, a: appState.currentColor.alpha)
        }

        // Try cmyk(c%, m%, y%, k%)
        if let values = extractValues(from: trimmed, prefix: "cmyk", count: 4) {
            let c = values[0] / 100.0
            let m = values[1] / 100.0
            let y = values[2] / 100.0
            let k = values[3] / 100.0
            guard c >= 0, c <= 1, m >= 0, m <= 1, y >= 0, y <= 1, k >= 0, k <= 1 else { return nil }
            return ColorModel.fromCMYK(c: c, m: m, y: y, k: k, a: appState.currentColor.alpha)
        }

        return nil
    }

    /// Extract numeric values from a string like "rgb(255, 128, 0)" → [255, 128, 0].
    /// Strips "%" symbols before parsing.
    private func extractValues(from input: String, prefix: String, count: Int) -> [CGFloat]? {
        guard input.hasPrefix(prefix + "(") && input.hasSuffix(")") else { return nil }
        let start = input.index(input.startIndex, offsetBy: prefix.count + 1)
        let end = input.index(before: input.endIndex)
        let inner = String(input[start..<end])
        let parts = inner.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
        }
        guard parts.count == count else { return nil }
        let values = parts.compactMap { CGFloat(Double($0) ?? .nan) }
        guard values.count == count, values.allSatisfy({ !$0.isNaN }) else { return nil }
        return values
    }
}
