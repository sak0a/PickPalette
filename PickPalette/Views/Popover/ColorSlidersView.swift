import SwiftUI

/// Displays the appropriate set of sliders for the active color space.
struct ColorSlidersView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 6) {
            switch appState.activeColorSpace {
            case .hsl:
                hslSliders
            case .hsb:
                hsbSliders
            case .rgb:
                rgbSliders
            case .cmyk:
                cmykSliders
            default:
                rgbSliders
            }
            alphaSlider
        }
    }

    // MARK: - HSL Sliders

    @ViewBuilder
    private var hslSliders: some View {
        GradientSliderView(
            label: "H",
            value: Binding(
                get: { appState.currentColor.hue },
                set: { newVal in
                    appState.currentColor = ColorModel.fromHSL(
                        h: newVal,
                        s: appState.currentColor.saturationHSL,
                        l: appState.currentColor.lightness,
                        a: appState.currentColor.alpha
                    )
                }
            ),
            range: 0...1,
            gradient: hueGradientColors,
            displayValue: "\(Int(round(appState.currentColor.hue * 360)))\u{00B0}"
        )
        GradientSliderView(
            label: "S",
            value: Binding(
                get: { appState.currentColor.saturationHSL },
                set: { newVal in
                    appState.currentColor = ColorModel.fromHSL(
                        h: appState.currentColor.hue,
                        s: newVal,
                        l: appState.currentColor.lightness,
                        a: appState.currentColor.alpha
                    )
                }
            ),
            range: 0...1,
            gradient: saturationHSLGradient,
            displayValue: "\(Int(round(appState.currentColor.saturationHSL * 100)))%"
        )
        GradientSliderView(
            label: "L",
            value: Binding(
                get: { appState.currentColor.lightness },
                set: { newVal in
                    appState.currentColor = ColorModel.fromHSL(
                        h: appState.currentColor.hue,
                        s: appState.currentColor.saturationHSL,
                        l: newVal,
                        a: appState.currentColor.alpha
                    )
                }
            ),
            range: 0...1,
            gradient: lightnessGradient,
            displayValue: "\(Int(round(appState.currentColor.lightness * 100)))%"
        )
    }

    // MARK: - HSB Sliders

    @ViewBuilder
    private var hsbSliders: some View {
        GradientSliderView(
            label: "H",
            value: Binding(
                get: { appState.currentColor.hueHSB },
                set: { newVal in
                    appState.currentColor = ColorModel.fromHSB(
                        h: newVal,
                        s: appState.currentColor.saturationHSB,
                        b: appState.currentColor.brightness,
                        a: appState.currentColor.alpha
                    )
                }
            ),
            range: 0...1,
            gradient: hueGradientColors,
            displayValue: "\(Int(round(appState.currentColor.hueHSB * 360)))\u{00B0}"
        )
        GradientSliderView(
            label: "S",
            value: Binding(
                get: { appState.currentColor.saturationHSB },
                set: { newVal in
                    appState.currentColor = ColorModel.fromHSB(
                        h: appState.currentColor.hueHSB,
                        s: newVal,
                        b: appState.currentColor.brightness,
                        a: appState.currentColor.alpha
                    )
                }
            ),
            range: 0...1,
            gradient: saturationHSBGradient,
            displayValue: "\(Int(round(appState.currentColor.saturationHSB * 100)))%"
        )
        GradientSliderView(
            label: "B",
            value: Binding(
                get: { appState.currentColor.brightness },
                set: { newVal in
                    appState.currentColor = ColorModel.fromHSB(
                        h: appState.currentColor.hueHSB,
                        s: appState.currentColor.saturationHSB,
                        b: newVal,
                        a: appState.currentColor.alpha
                    )
                }
            ),
            range: 0...1,
            gradient: brightnessGradient,
            displayValue: "\(Int(round(appState.currentColor.brightness * 100)))%"
        )
    }

    // MARK: - RGB Sliders

    @ViewBuilder
    private var rgbSliders: some View {
        GradientSliderView(
            label: "R",
            value: Binding(
                get: { appState.currentColor.red },
                set: { appState.currentColor.red = $0 }
            ),
            range: 0...1,
            gradient: redGradient,
            displayValue: "\(Int(round(appState.currentColor.red * 255)))"
        )
        GradientSliderView(
            label: "G",
            value: Binding(
                get: { appState.currentColor.green },
                set: { appState.currentColor.green = $0 }
            ),
            range: 0...1,
            gradient: greenGradient,
            displayValue: "\(Int(round(appState.currentColor.green * 255)))"
        )
        GradientSliderView(
            label: "B",
            value: Binding(
                get: { appState.currentColor.blue },
                set: { appState.currentColor.blue = $0 }
            ),
            range: 0...1,
            gradient: blueGradient,
            displayValue: "\(Int(round(appState.currentColor.blue * 255)))"
        )
    }

    // MARK: - CMYK Sliders

    @ViewBuilder
    private var cmykSliders: some View {
        GradientSliderView(
            label: "C",
            value: Binding(
                get: { appState.currentColor.cyan },
                set: { newVal in
                    let col = appState.currentColor
                    appState.currentColor = ColorModel.fromCMYK(
                        c: newVal, m: col.magenta, y: col.yellow, k: col.key,
                        a: col.alpha
                    )
                }
            ),
            range: 0...1,
            gradient: cyanGradient,
            displayValue: "\(Int(round(appState.currentColor.cyan * 100)))%"
        )
        GradientSliderView(
            label: "M",
            value: Binding(
                get: { appState.currentColor.magenta },
                set: { newVal in
                    let col = appState.currentColor
                    appState.currentColor = ColorModel.fromCMYK(
                        c: col.cyan, m: newVal, y: col.yellow, k: col.key,
                        a: col.alpha
                    )
                }
            ),
            range: 0...1,
            gradient: magentaGradient,
            displayValue: "\(Int(round(appState.currentColor.magenta * 100)))%"
        )
        GradientSliderView(
            label: "Y",
            value: Binding(
                get: { appState.currentColor.yellow },
                set: { newVal in
                    let col = appState.currentColor
                    appState.currentColor = ColorModel.fromCMYK(
                        c: col.cyan, m: col.magenta, y: newVal, k: col.key,
                        a: col.alpha
                    )
                }
            ),
            range: 0...1,
            gradient: yellowGradient,
            displayValue: "\(Int(round(appState.currentColor.yellow * 100)))%"
        )
        GradientSliderView(
            label: "K",
            value: Binding(
                get: { appState.currentColor.key },
                set: { newVal in
                    let col = appState.currentColor
                    appState.currentColor = ColorModel.fromCMYK(
                        c: col.cyan, m: col.magenta, y: col.yellow, k: newVal,
                        a: col.alpha
                    )
                }
            ),
            range: 0...1,
            gradient: keyGradient,
            displayValue: "\(Int(round(appState.currentColor.key * 100)))%"
        )
    }

    // MARK: - Alpha Slider

    private var alphaSlider: some View {
        GradientSliderView(
            label: "A",
            value: Binding(
                get: { appState.currentColor.alpha },
                set: { appState.currentColor.alpha = $0 }
            ),
            range: 0...1,
            gradient: alphaGradient,
            displayValue: "\(Int(round(appState.currentColor.alpha * 100)))%"
        )
    }

    // MARK: - Gradient Colors

    private var hueGradientColors: [Color] {
        (0...12).map { i in
            ColorModel.fromHSL(h: CGFloat(i) / 12.0, s: 1, l: 0.5).color
        }
    }

    private var saturationHSLGradient: [Color] {
        let h = appState.currentColor.hue
        let l = appState.currentColor.lightness
        return [
            ColorModel.fromHSL(h: h, s: 0, l: l).color,
            ColorModel.fromHSL(h: h, s: 1, l: l).color
        ]
    }

    private var lightnessGradient: [Color] {
        let h = appState.currentColor.hue
        let s = appState.currentColor.saturationHSL
        return [
            ColorModel.fromHSL(h: h, s: s, l: 0).color,
            ColorModel.fromHSL(h: h, s: s, l: 0.5).color,
            ColorModel.fromHSL(h: h, s: s, l: 1).color
        ]
    }

    private var saturationHSBGradient: [Color] {
        let h = appState.currentColor.hueHSB
        let b = appState.currentColor.brightness
        return [
            ColorModel.fromHSB(h: h, s: 0, b: b).color,
            ColorModel.fromHSB(h: h, s: 1, b: b).color
        ]
    }

    private var brightnessGradient: [Color] {
        let h = appState.currentColor.hueHSB
        let s = appState.currentColor.saturationHSB
        return [
            ColorModel.fromHSB(h: h, s: s, b: 0).color,
            ColorModel.fromHSB(h: h, s: s, b: 1).color
        ]
    }

    private var redGradient: [Color] {
        let c = appState.currentColor
        return [
            ColorModel(red: 0, green: c.green, blue: c.blue).color,
            ColorModel(red: 1, green: c.green, blue: c.blue).color
        ]
    }

    private var greenGradient: [Color] {
        let c = appState.currentColor
        return [
            ColorModel(red: c.red, green: 0, blue: c.blue).color,
            ColorModel(red: c.red, green: 1, blue: c.blue).color
        ]
    }

    private var blueGradient: [Color] {
        let c = appState.currentColor
        return [
            ColorModel(red: c.red, green: c.green, blue: 0).color,
            ColorModel(red: c.red, green: c.green, blue: 1).color
        ]
    }

    private var alphaGradient: [Color] {
        let c = appState.currentColor
        return [
            ColorModel(red: c.red, green: c.green, blue: c.blue, alpha: 0).color,
            ColorModel(red: c.red, green: c.green, blue: c.blue, alpha: 1).color
        ]
    }

    // MARK: - CMYK Gradients

    private var cyanGradient: [Color] {
        let col = appState.currentColor
        return [
            ColorModel.fromCMYK(c: 0, m: col.magenta, y: col.yellow, k: col.key, a: col.alpha).color,
            ColorModel.fromCMYK(c: 1, m: col.magenta, y: col.yellow, k: col.key, a: col.alpha).color
        ]
    }

    private var magentaGradient: [Color] {
        let col = appState.currentColor
        return [
            ColorModel.fromCMYK(c: col.cyan, m: 0, y: col.yellow, k: col.key, a: col.alpha).color,
            ColorModel.fromCMYK(c: col.cyan, m: 1, y: col.yellow, k: col.key, a: col.alpha).color
        ]
    }

    private var yellowGradient: [Color] {
        let col = appState.currentColor
        return [
            ColorModel.fromCMYK(c: col.cyan, m: col.magenta, y: 0, k: col.key, a: col.alpha).color,
            ColorModel.fromCMYK(c: col.cyan, m: col.magenta, y: 1, k: col.key, a: col.alpha).color
        ]
    }

    private var keyGradient: [Color] {
        let col = appState.currentColor
        return [
            ColorModel.fromCMYK(c: col.cyan, m: col.magenta, y: col.yellow, k: 0, a: col.alpha).color,
            ColorModel.fromCMYK(c: col.cyan, m: col.magenta, y: col.yellow, k: 1, a: col.alpha).color
        ]
    }
}
