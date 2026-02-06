import SwiftUI

/// Horizontal strip of recent color swatches — glass capsule style.
struct RecentColorsView: View {
    @Bindable var appState: AppState

    var body: some View {
        if !appState.recentColors.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(appState.recentColors) { color in
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
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .frame(height: 28)
        }
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
