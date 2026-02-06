import SwiftUI
import AppKit

/// Single source of truth for color data. Stores RGBA internally;
/// all other color spaces are computed bidirectionally.
struct ColorModel: Equatable, Codable, Identifiable {
    let id: UUID
    var red: CGFloat   // 0–1
    var green: CGFloat // 0–1
    var blue: CGFloat  // 0–1
    var alpha: CGFloat // 0–1

    // MARK: - Init

    init(id: UUID = UUID(), red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        self.id = id
        self.red = Self.clamp01(red)
        self.green = Self.clamp01(green)
        self.blue = Self.clamp01(blue)
        self.alpha = Self.clamp01(alpha)
    }

    init(id: UUID = UUID(), nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.id = id
        self.red = Self.clamp01(c.redComponent)
        self.green = Self.clamp01(c.greenComponent)
        self.blue = Self.clamp01(c.blueComponent)
        self.alpha = Self.clamp01(c.alphaComponent)
    }

    // MARK: - HSL

    var hue: CGFloat {
        get { hslComponents.h }
        set { setHSL(h: newValue, s: saturationHSL, l: lightness) }
    }

    var saturationHSL: CGFloat {
        get { hslComponents.s }
        set { setHSL(h: hue, s: newValue, l: lightness) }
    }

    var lightness: CGFloat {
        get { hslComponents.l }
        set { setHSL(h: hue, s: saturationHSL, l: newValue) }
    }

    // MARK: - HSB

    var hueHSB: CGFloat {
        get { hsbComponents.h }
        set { setHSB(h: newValue, s: saturationHSB, b: brightness) }
    }

    var saturationHSB: CGFloat {
        get { hsbComponents.s }
        set { setHSB(h: hueHSB, s: newValue, b: brightness) }
    }

    var brightness: CGFloat {
        get { hsbComponents.b }
        set { setHSB(h: hueHSB, s: saturationHSB, b: newValue) }
    }

    // MARK: - CMYK

    var cyan: CGFloat { cmykComponents.c }
    var magenta: CGFloat { cmykComponents.m }
    var yellow: CGFloat { cmykComponents.y }
    var key: CGFloat { cmykComponents.k }

    // MARK: - Hex

    var hexString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var hexaString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        let a = Int(round(alpha * 255))
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }

    // MARK: - NSColor / Color

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    // MARK: - Static Constructors

    static func fromHSL(h: CGFloat, s: CGFloat, l: CGFloat, a: CGFloat = 1.0) -> ColorModel {
        var model = ColorModel(red: 0, green: 0, blue: 0, alpha: a)
        model.setHSL(h: h, s: s, l: l)
        return model
    }

    static func fromHSB(h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat = 1.0) -> ColorModel {
        var model = ColorModel(red: 0, green: 0, blue: 0, alpha: a)
        model.setHSB(h: h, s: s, b: b)
        return model
    }

    static func fromHex(_ hex: String) -> ColorModel? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }

        var hexValue: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&hexValue) else { return nil }

        let r, g, b, a: CGFloat
        switch hexSanitized.count {
        case 3: // RGB shorthand
            r = CGFloat((hexValue & 0xF00) >> 8) / 15.0
            g = CGFloat((hexValue & 0x0F0) >> 4) / 15.0
            b = CGFloat(hexValue & 0x00F) / 15.0
            a = 1.0
        case 4: // RGBA shorthand
            r = CGFloat((hexValue & 0xF000) >> 12) / 15.0
            g = CGFloat((hexValue & 0x0F00) >> 8) / 15.0
            b = CGFloat((hexValue & 0x00F0) >> 4) / 15.0
            a = CGFloat(hexValue & 0x000F) / 15.0
        case 6: // RRGGBB
            r = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((hexValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat(hexValue & 0x0000FF) / 255.0
            a = 1.0
        case 8: // RRGGBBAA
            r = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
            g = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((hexValue & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(hexValue & 0x000000FF) / 255.0
        default:
            return nil
        }
        return ColorModel(red: r, green: g, blue: b, alpha: a)
    }

    static func fromCMYK(c: CGFloat, m: CGFloat, y: CGFloat, k: CGFloat, a: CGFloat = 1.0) -> ColorModel {
        let r = (1 - c) * (1 - k)
        let g = (1 - m) * (1 - k)
        let b = (1 - y) * (1 - k)
        return ColorModel(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Private Conversion Helpers

private extension ColorModel {

    static func clamp01(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    // MARK: RGB → HSL

    var hslComponents: (h: CGFloat, s: CGFloat, l: CGFloat) {
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let delta = maxC - minC
        let l = (maxC + minC) / 2.0

        if delta < 1e-10 {
            return (h: 0, s: 0, l: l)
        }

        let s: CGFloat
        if l <= 0.5 {
            s = delta / (maxC + minC)
        } else {
            s = delta / (2.0 - maxC - minC)
        }

        var h: CGFloat
        if red == maxC {
            h = (green - blue) / delta
            if green < blue { h += 6.0 }
        } else if green == maxC {
            h = 2.0 + (blue - red) / delta
        } else {
            h = 4.0 + (red - green) / delta
        }
        h /= 6.0 // normalize to 0–1

        return (h: h, s: s, l: l)
    }

    // MARK: HSL → RGB

    mutating func setHSL(h: CGFloat, s: CGFloat, l: CGFloat) {
        let h = Self.clamp01(h)
        let s = Self.clamp01(s)
        let l = Self.clamp01(l)

        if s < 1e-10 {
            red = l; green = l; blue = l
            return
        }

        let q: CGFloat = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p: CGFloat = 2 * l - q

        red = Self.hueToRGB(p: p, q: q, t: h + 1.0 / 3.0)
        green = Self.hueToRGB(p: p, q: q, t: h)
        blue = Self.hueToRGB(p: p, q: q, t: h - 1.0 / 3.0)
    }

    static func hueToRGB(p: CGFloat, q: CGFloat, t: CGFloat) -> CGFloat {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1.0 / 6.0 { return p + (q - p) * 6.0 * t }
        if t < 1.0 / 2.0 { return q }
        if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6.0 }
        return p
    }

    // MARK: RGB → HSB

    var hsbComponents: (h: CGFloat, s: CGFloat, b: CGFloat) {
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let delta = maxC - minC

        let b = maxC

        if delta < 1e-10 {
            return (h: 0, s: 0, b: b)
        }

        let s = delta / maxC

        var h: CGFloat
        if red == maxC {
            h = (green - blue) / delta
            if green < blue { h += 6.0 }
        } else if green == maxC {
            h = 2.0 + (blue - red) / delta
        } else {
            h = 4.0 + (red - green) / delta
        }
        h /= 6.0

        return (h: h, s: s, b: b)
    }

    // MARK: HSB → RGB

    mutating func setHSB(h: CGFloat, s: CGFloat, b: CGFloat) {
        let h = Self.clamp01(h)
        let s = Self.clamp01(s)
        let b = Self.clamp01(b)

        if s < 1e-10 {
            red = b; green = b; blue = b
            return
        }

        let i = Int(h * 6.0) % 6
        let f = h * 6.0 - CGFloat(i)
        let p = b * (1.0 - s)
        let q = b * (1.0 - f * s)
        let t = b * (1.0 - (1.0 - f) * s)

        switch i {
        case 0: red = b; green = t; blue = p
        case 1: red = q; green = b; blue = p
        case 2: red = p; green = b; blue = t
        case 3: red = p; green = q; blue = b
        case 4: red = t; green = p; blue = b
        default: red = b; green = p; blue = q
        }
    }

    // MARK: RGB → CMYK

    var cmykComponents: (c: CGFloat, m: CGFloat, y: CGFloat, k: CGFloat) {
        let k = 1.0 - max(red, green, blue)
        if k >= 1.0 - 1e-10 {
            return (c: 0, m: 0, y: 0, k: 1)
        }
        let c = (1.0 - red - k) / (1.0 - k)
        let m = (1.0 - green - k) / (1.0 - k)
        let y = (1.0 - blue - k) / (1.0 - k)
        return (c: c, m: m, y: y, k: k)
    }
}

// MARK: - Common Colors

extension ColorModel {
    static let white = ColorModel(red: 1, green: 1, blue: 1)
    static let black = ColorModel(red: 0, green: 0, blue: 0)
    static let clear = ColorModel(red: 0, green: 0, blue: 0, alpha: 0)
    static let defaultColor = ColorModel(red: 110/255, green: 133/255, blue: 247/255)
}
