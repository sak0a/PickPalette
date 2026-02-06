import SwiftUI
import AppKit

/// Adaptive color picker area.
/// HSL/HSB: rectangular saturation-brightness picker with hue from slider.
/// RGB: full color wheel showing all hues.
struct SpectrumPickerView: View {
    @Bindable var appState: AppState
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            switch appState.activeColorSpace {
            case .rgb:
                ColorWheelView(appState: appState, diameter: min(width, height))
                    .frame(width: width, height: height)
            case .hsl:
                HSLSquarePickerView(appState: appState, width: width, height: height)
            case .hsb:
                HSBSquarePickerView(appState: appState, width: width, height: height)
            case .cmyk:
                ColorWheelView(appState: appState, diameter: min(width, height))
                    .frame(width: width, height: height)
            default:
                HSLSquarePickerView(appState: appState, width: width, height: height)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.activeColorSpace)
    }
}

// MARK: - Color Wheel (for RGB mode)

struct ColorWheelView: View {
    @Bindable var appState: AppState
    let diameter: CGFloat

    private var indicatorPosition: CGPoint {
        let c = appState.currentColor
        let h = c.hueHSB
        let s = c.saturationHSB

        let radius = (diameter / 2) * s
        let angle = h * 2 * .pi - .pi / 2 // start from top
        let cx = diameter / 2 + radius * cos(angle)
        let cy = diameter / 2 + radius * sin(angle)
        return CGPoint(x: cx, y: cy)
    }

    var body: some View {
        ZStack {
            // Color wheel rendered as CGImage
            Canvas { context, size in
                if let wheelImage = generateColorWheel(size: size) {
                    context.draw(Image(decorative: wheelImage, scale: 1), in: CGRect(origin: .zero, size: size))
                }
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())

            // Brightness overlay — dark center for low brightness
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.black.opacity(1 - appState.currentColor.brightness), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    )
                )
                .frame(width: diameter, height: diameter)
                .allowsHitTesting(false)

            // Indicator
            Circle()
                .fill(appState.currentColor.color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .strokeBorder(.white, lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                .position(indicatorPosition)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleWheelDrag(at: value.location)
                }
        )
        .accessibilityLabel("Color wheel")
        .accessibilityHint("Drag to select hue and saturation")
    }

    private func handleWheelDrag(at point: CGPoint) {
        let center = CGPoint(x: diameter / 2, y: diameter / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let maxRadius = diameter / 2

        let saturation = min(distance / maxRadius, 1.0)
        var angle = atan2(dy, dx) + .pi / 2 // adjust so top is 0
        if angle < 0 { angle += 2 * .pi }
        let hue = angle / (2 * .pi)

        let newColor = ColorModel.fromHSB(
            h: hue,
            s: saturation,
            b: appState.currentColor.brightness,
            a: appState.currentColor.alpha
        )
        appState.currentColor = newColor
    }

    private func generateColorWheel(size: CGSize) -> CGImage? {
        let w = Int(size.width)
        let h = Int(size.height)
        guard w > 0, h > 0 else { return nil }

        let center = CGPoint(x: CGFloat(w) / 2, y: CGFloat(h) / 2)
        let maxR = min(CGFloat(w), CGFloat(h)) / 2

        var pixels = [UInt8](repeating: 0, count: w * h * 4)

        for py in 0..<h {
            for px in 0..<w {
                let dx = CGFloat(px) - center.x
                let dy = CGFloat(py) - center.y
                let dist = sqrt(dx * dx + dy * dy)

                let idx = (py * w + px) * 4

                if dist <= maxR {
                    var angle = atan2(dy, dx) + .pi / 2
                    if angle < 0 { angle += 2 * .pi }
                    let hue = angle / (2 * .pi)
                    let sat = dist / maxR

                    let color = ColorModel.fromHSB(h: hue, s: sat, b: 1.0)
                    pixels[idx + 0] = UInt8(round(color.red * 255))
                    pixels[idx + 1] = UInt8(round(color.green * 255))
                    pixels[idx + 2] = UInt8(round(color.blue * 255))
                    pixels[idx + 3] = 255
                } else {
                    pixels[idx + 3] = 0
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        return ctx.makeImage()
    }
}

// MARK: - HSL Square Picker

struct HSLSquarePickerView: View {
    @Bindable var appState: AppState
    let width: CGFloat
    let height: CGFloat

    private var indicatorPosition: CGPoint {
        let c = appState.currentColor
        return CGPoint(
            x: c.hue * width,
            y: (1 - c.saturationHSL) * height
        )
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                drawHSLSpectrum(context: context, size: size)
            }
            .frame(width: width, height: height)

            // Indicator
            Circle()
                .fill(appState.currentColor.color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .strokeBorder(.white, lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                .position(indicatorPosition)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let x = min(max(value.location.x / width, 0), 1)
                    let y = min(max(1 - value.location.y / height, 0), 1)
                    appState.currentColor = ColorModel.fromHSL(
                        h: x, s: y,
                        l: appState.currentColor.lightness,
                        a: appState.currentColor.alpha
                    )
                }
        )
        .accessibilityLabel("HSL color picker")
        .accessibilityHint("Drag to select hue and saturation")
    }

    private func drawHSLSpectrum(context: GraphicsContext, size: CGSize) {
        let step = 3
        let cols = Int(size.width) / step
        let rows = Int(size.height) / step
        let l = appState.currentColor.lightness

        for col in 0..<cols {
            for row in 0..<rows {
                let h = CGFloat(col) / CGFloat(cols)
                let s = 1.0 - CGFloat(row) / CGFloat(rows)
                let cm = ColorModel.fromHSL(h: h, s: s, l: l)
                let rect = CGRect(x: CGFloat(col * step), y: CGFloat(row * step), width: CGFloat(step), height: CGFloat(step))
                context.fill(Path(rect), with: .color(cm.color))
            }
        }
    }
}

// MARK: - HSB Square Picker

struct HSBSquarePickerView: View {
    @Bindable var appState: AppState
    let width: CGFloat
    let height: CGFloat

    private var indicatorPosition: CGPoint {
        let c = appState.currentColor
        return CGPoint(
            x: c.saturationHSB * width,
            y: (1 - c.brightness) * height
        )
    }

    var body: some View {
        ZStack {
            // Hue base
            Rectangle()
                .fill(Color(hue: appState.currentColor.hueHSB, saturation: 1, brightness: 1))

            // White gradient left to right (saturation)
            LinearGradient(
                colors: [.white, .white.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Black gradient bottom to top (brightness)
            LinearGradient(
                colors: [.black, .black.opacity(0)],
                startPoint: .bottom,
                endPoint: .top
            )

            // Indicator
            Circle()
                .fill(appState.currentColor.color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .strokeBorder(.white, lineWidth: 2.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                .position(indicatorPosition)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let x = min(max(value.location.x / width, 0), 1)
                    let y = min(max(1 - value.location.y / height, 0), 1)
                    appState.currentColor = ColorModel.fromHSB(
                        h: appState.currentColor.hueHSB,
                        s: x,
                        b: y,
                        a: appState.currentColor.alpha
                    )
                }
        )
        .accessibilityLabel("HSB color picker")
        .accessibilityHint("Drag to select saturation and brightness")
    }
}
