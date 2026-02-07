import SwiftUI

/// Adaptive grid of recent color swatches — flows into multiple rows when resized taller.
struct RecentColorsView: View {
    @Bindable var appState: AppState
    let width: CGFloat
    let height: CGFloat

    private let swatchSize: CGFloat = 22  // selected swatch diameter (largest)
    private let spacing: CGFloat = 5
    private let padding: CGFloat = 2

    private var cellSize: CGFloat { swatchSize + spacing }

    /// Number of rows that fit in the available height.
    private var rowCount: Int {
        max(1, Int((height - 2 * padding + spacing) / cellSize))
    }

    /// Number of columns that fit in the available width.
    private var columnCount: Int {
        max(1, Int((width - 2 * padding + spacing) / cellSize))
    }

    var body: some View {
        if !appState.recentColors.isEmpty {
            if rowCount <= 1 {
                singleRowLayout
            } else {
                multiRowLayout
            }
        }
    }

    // MARK: - Single Row (original horizontal scroll behavior)

    private var singleRowLayout: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(appState.recentColors) { color in
                    swatchView(for: color)
                }
            }
            .padding(.horizontal, padding)
            .padding(.vertical, padding)
        }
    }

    // MARK: - Multi-Row (vertical scroll with wrapped rows)

    private var multiRowLayout: some View {
        let cols = columnCount
        let rows = chunked(appState.recentColors, size: cols)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: spacing) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: spacing) {
                        ForEach(rows[rowIndex]) { color in
                            swatchView(for: color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(padding)
        }
    }

    // MARK: - Swatch Builder

    private func swatchView(for color: ColorModel) -> some View {
        RecentColorSwatch(
            color: color,
            isSelected: isSameColor(color, appState.currentColor)
        ) {
            withAnimation(.spring(duration: 0.2)) {
                appState.setColor(color)
            }
        }
    }

    // MARK: - Helpers

    private func isSameColor(_ a: ColorModel, _ b: ColorModel) -> Bool {
        abs(a.red - b.red) < 0.01 && abs(a.green - b.green) < 0.01 && abs(a.blue - b.blue) < 0.01
    }

    private func chunked(_ array: [ColorModel], size: Int) -> [[ColorModel]] {
        stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
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
