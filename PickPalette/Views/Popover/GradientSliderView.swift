import SwiftUI

/// A custom slider with a gradient track — macOS Tahoe glass style.
struct GradientSliderView: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let gradient: [Color]
    let displayValue: String
    var onEditingChanged: ((Bool) -> Void)? = nil

    private let trackHeight: CGFloat = 12
    private let thumbSize: CGFloat = 16

    @State private var isDragging = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Channel label
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
                .frame(width: 14, alignment: .center)

            // Slider track
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let thumbX = normalizedValue * (trackWidth - thumbSize) + thumbSize / 2

                ZStack(alignment: .leading) {
                    // Track background with gradient
                    ZStack {
                        if label == "A" {
                            // Checkerboard for alpha
                            checkerboard
                                .frame(height: trackHeight)
                                .clipShape(Capsule())
                        }

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: gradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: trackHeight)
                    }

                    // Glass border on track
                    Capsule()
                        .strokeBorder(colorScheme == .dark ? .white.opacity(0.15) : .black.opacity(0.10), lineWidth: 0.5)
                        .frame(height: trackHeight)

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.15), radius: isDragging ? 3 : 1.5, y: isDragging ? 2 : 1)
                        .overlay(
                            Circle()
                                .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                        )
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                        .position(x: thumbX, y: geo.size.height / 2)
                        .animation(.spring(duration: 0.2), value: isDragging)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            isDragging = true
                            let fraction = (drag.location.x - thumbSize / 2) / (trackWidth - thumbSize)
                            let clamped = min(max(fraction, 0), 1)
                            value = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                            onEditingChanged?(true)
                        }
                        .onEnded { _ in
                            isDragging = false
                            onEditingChanged?(false)
                        }
                )
            }
            .frame(height: thumbSize + 4)

            // Numeric display — compact, no background
            Text(displayValue)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .fixedSize()
        }
        .frame(height: 22)
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 4
            let cols = Int(ceil(size.width / cellSize))
            let rows = Int(ceil(size.height / cellSize))
            for col in 0..<cols {
                for row in 0..<rows {
                    let isLight = (col + row) % 2 == 0
                    let rect = CGRect(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize, width: cellSize, height: cellSize)
                    context.fill(Path(rect), with: .color(isLight ? Color.white : Color(white: 0.82)))
                }
            }
        }
    }
}
