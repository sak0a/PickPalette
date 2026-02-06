import SwiftUI

enum PopoverTheme {
    static func rootBackground(useGlassStyle: Bool, colorScheme: ColorScheme) -> AnyShapeStyle {
        if useGlassStyle {
            if colorScheme == .dark {
                return AnyShapeStyle(.ultraThinMaterial.opacity(0.72))
            }
            return AnyShapeStyle(.thickMaterial.opacity(0.96))
        }

        return AnyShapeStyle(
            colorScheme == .dark
                ? Color(white: 0.10).opacity(0.94)
                : Color.white.opacity(0.88)
        )
    }

    static func panelBackground(useGlassStyle: Bool, colorScheme: ColorScheme) -> AnyShapeStyle {
        if useGlassStyle {
            if colorScheme == .dark {
                return AnyShapeStyle(.ultraThinMaterial.opacity(0.62))
            }
            return AnyShapeStyle(.regularMaterial.opacity(0.94))
        }

        return AnyShapeStyle(
            colorScheme == .dark
                ? Color(white: 0.15).opacity(0.92)
                : Color.white.opacity(0.86)
        )
    }

    static func controlBackground(useGlassStyle: Bool, colorScheme: ColorScheme) -> AnyShapeStyle {
        if useGlassStyle {
            if colorScheme == .dark {
                return AnyShapeStyle(.thinMaterial.opacity(0.92))
            }
            return AnyShapeStyle(.thickMaterial.opacity(0.98))
        }

        return AnyShapeStyle(
            colorScheme == .dark
                ? Color(white: 0.20).opacity(0.92)
                : Color.white.opacity(0.93)
        )
    }

    static func subtleFill(useGlassStyle: Bool, colorScheme: ColorScheme) -> Color {
        if useGlassStyle {
            return colorScheme == .dark ? .white.opacity(0.09) : .black.opacity(0.06)
        }
        return colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.08)
    }

    static func subtleStroke(useGlassStyle: Bool, colorScheme: ColorScheme) -> Color {
        if useGlassStyle {
            return colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.08)
        }
        return colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.10)
    }

    static func primaryTextColor(useGlassStyle: Bool, colorScheme: ColorScheme) -> Color {
        if useGlassStyle {
            return colorScheme == .dark ? .white.opacity(0.93) : .black.opacity(0.84)
        }
        return colorScheme == .dark ? .white.opacity(0.94) : .black.opacity(0.88)
    }

    static func secondaryTextColor(useGlassStyle: Bool, colorScheme: ColorScheme) -> Color {
        if useGlassStyle {
            return colorScheme == .dark ? .white.opacity(0.78) : .black.opacity(0.70)
        }
        return colorScheme == .dark ? .white.opacity(0.80) : .black.opacity(0.74)
    }

    static func bannerBackground(useGlassStyle: Bool, colorScheme: ColorScheme) -> Color {
        if useGlassStyle {
            return colorScheme == .dark ? .black.opacity(0.48) : .white.opacity(0.88)
        }
        return colorScheme == .dark ? .black.opacity(0.55) : .white.opacity(0.80)
    }
}
