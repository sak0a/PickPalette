import SwiftUI

/// Horizontal strip of recent color swatches — glass capsule style.
struct RecentColorsView: View {
    @Bindable var appState: AppState
    var availableWidth: CGFloat = 252

    private let swatchSize: CGFloat = 22
    private let spacing: CGFloat = 5
    private let hPadding: CGFloat = 2

    /// How many full swatches fit without being clipped.
    private var visibleCount: Int {
        let usable = availableWidth - hPadding * 2
        guard usable > 0 else { return 0 }
        // Each swatch takes swatchSize + spacing, last one doesn't need trailing spacing
        let count = Int((usable + spacing) / (swatchSize + spacing))
        return max(0, count)
    }

    private var displayColors: [ColorModel] {
        if appState.recentColorsScrollEnabled {
            return appState.recentColors
        } else {
            return Array(appState.recentColors.prefix(visibleCount))
        }
    }

    var body: some View {
        if !appState.recentColors.isEmpty {
            Group {
                if appState.recentColorsScrollEnabled {
                    ScrollView(.horizontal, showsIndicators: false) {
                        recentColorsContent
                    }
                } else {
                    recentColorsContent
                }
            }
            .frame(height: 28)
        }
    }

    private var recentColorsContent: some View {
        HStack(spacing: spacing) {
            ForEach(displayColors) { color in
                RecentColorSwatch(
                    color: color,
                    isSelected: isSameColor(color, appState.currentColor)
                ) {
                    withAnimation(.spring(duration: 0.2)) {
                        appState.setColor(color)
                    }
                }
            }
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, 2)
    }

    private func isSameColor(_ a: ColorModel, _ b: ColorModel) -> Bool {
        abs(a.red - b.red) < 0.01 && abs(a.green - b.green) < 0.01 && abs(a.blue - b.blue) < 0.01
    }
}

struct RecentColorSwatch: View {
    let color: ColorModel
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Circle()
            .fill(color.color)
            .frame(width: isSelected ? 22 : 18, height: isSelected ? 22 : 18)
            .overlay(
                Circle()
                    .strokeBorder(
                        colorScheme == .dark
                            ? .white.opacity(isSelected ? 0.6 : 0.2)
                            : .black.opacity(isSelected ? 0.24 : 0.10),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
            .shadow(color: isHovering ? color.color.opacity(0.4) : .clear, radius: 4)
            .scaleEffect(isHovering ? 1.15 : 1.0)
            .animation(.spring(duration: 0.2), value: isHovering)
            .animation(.spring(duration: 0.2), value: isSelected)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture(perform: action)
            .help(color.hexString)
    }
}
