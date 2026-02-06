import Foundation

// MARK: - Color Channel

enum ColorChannel: String, Codable, CaseIterable, Identifiable {
    case red, green, blue, alpha
    case hue, saturation, lightness, brightness
    case cyan, magenta, yellow, key
    case hex, hexAlpha

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        case .alpha: return "Alpha"
        case .hue: return "Hue"
        case .saturation: return "Saturation"
        case .lightness: return "Lightness"
        case .brightness: return "Brightness"
        case .cyan: return "Cyan"
        case .magenta: return "Magenta"
        case .yellow: return "Yellow"
        case .key: return "Black"
        case .hex: return "Hex"
        case .hexAlpha: return "Hex Alpha"
        }
    }

    var colorSpaceGroup: ColorSpaceGroup {
        switch self {
        case .red, .green, .blue, .alpha: return .rgb
        case .hue, .saturation, .lightness: return .hsl
        case .brightness: return .hsb
        case .cyan, .magenta, .yellow, .key: return .cmyk
        case .hex, .hexAlpha: return .hex
        }
    }
}

enum ColorSpaceGroup: String, Codable, CaseIterable, Hashable {
    case rgb, hsl, hsb, cmyk, hex

    var displayName: String { rawValue.uppercased() }

    var channels: [ColorChannel] {
        switch self {
        case .rgb: return [.red, .green, .blue, .alpha]
        case .hsl: return [.hue, .saturation, .lightness]
        case .hsb: return [.hue, .saturation, .brightness]
        case .cmyk: return [.cyan, .magenta, .yellow, .key]
        case .hex: return [.hex, .hexAlpha]
        }
    }
}

// MARK: - Display Mode

enum DisplayMode: String, Codable, CaseIterable {
    case number   // 0–255 for RGB, 0–360 for hue, 0–100 for SL
    case percent  // 0%–100%
    case decimal  // 0.0–1.0

    var displayName: String {
        switch self {
        case .number: return "Number"
        case .percent: return "Percent"
        case .decimal: return "Decimal"
        }
    }
}

// MARK: - Format Token

enum FormatToken: Codable, Equatable, Identifiable {
    case literal(String)
    case channel(ColorChannel, DisplayMode, Int) // channel, mode, decimal precision

    var id: String {
        switch self {
        case .literal(let s): return "lit_\(s)"
        case .channel(let ch, let mode, let prec): return "ch_\(ch.rawValue)_\(mode.rawValue)_\(prec)"
        }
    }

    var displayLabel: String {
        switch self {
        case .literal(let s): return s
        case .channel(let ch, _, _): return ch.displayName
        }
    }

    func resolve(with color: ColorModel) -> String {
        switch self {
        case .literal(let s):
            return s
        case .channel(let channel, let mode, let precision):
            return Self.formatChannel(channel, mode: mode, precision: precision, color: color)
        }
    }

    private static func formatChannel(_ channel: ColorChannel, mode: DisplayMode, precision: Int, color: ColorModel) -> String {
        switch channel {
        case .hex:
            // Hex ignores display mode
            let hex = color.hexString
            return String(hex.dropFirst()) // remove #
        case .hexAlpha:
            let a = Int(round(color.alpha * 255))
            return String(format: "%02X", a)
        default:
            let rawValue = channelRawValue(channel, color: color)
            return formatValue(rawValue, channel: channel, mode: mode, precision: precision)
        }
    }

    private static func channelRawValue(_ channel: ColorChannel, color: ColorModel) -> CGFloat {
        switch channel {
        case .red: return color.red
        case .green: return color.green
        case .blue: return color.blue
        case .alpha: return color.alpha
        case .hue: return color.hue
        case .saturation: return color.saturationHSL
        case .lightness: return color.lightness
        case .brightness: return color.brightness
        case .cyan: return color.cyan
        case .magenta: return color.magenta
        case .yellow: return color.yellow
        case .key: return color.key
        case .hex, .hexAlpha: return 0 // handled above
        }
    }

    private static func formatValue(_ raw: CGFloat, channel: ColorChannel, mode: DisplayMode, precision: Int) -> String {
        let value: CGFloat
        switch mode {
        case .decimal:
            value = raw
        case .percent:
            value = raw * 100
        case .number:
            switch channel {
            case .red, .green, .blue: value = raw * 255
            case .hue: value = raw * 360
            case .alpha: value = raw * 100
            default: value = raw * 100 // S, L, B, CMYK all 0–100
            }
        }

        if precision == 0 {
            return "\(Int(round(value)))"
        } else {
            return String(format: "%.\(precision)f", value)
        }
    }
}

// MARK: - Color Format

struct ColorFormat: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var tokens: [FormatToken]
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, tokens: [FormatToken], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.tokens = tokens
        self.isBuiltIn = isBuiltIn
    }

    func format(color: ColorModel) -> String {
        tokens.map { $0.resolve(with: color) }.joined()
    }
}

// MARK: - Built-in Formats

extension ColorFormat {
    static let builtInFormats: [ColorFormat] = [
        hexFormat, hexaFormat, rgbaFormat, hslaFormat, hsbaFormat, cmykFormat
    ]

    // Deterministic UUIDs so the default selection survives app restarts
    static let hexFormat = ColorFormat(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "HEX",
        tokens: [
            .literal("#"),
            .channel(.hex, .number, 0)
        ],
        isBuiltIn: true
    )

    static let hexaFormat = ColorFormat(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "HEXA",
        tokens: [
            .literal("#"),
            .channel(.hex, .number, 0),
            .channel(.hexAlpha, .number, 0)
        ],
        isBuiltIn: true
    )

    static let rgbaFormat = ColorFormat(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "RGBA",
        tokens: [
            .literal("rgba("),
            .channel(.red, .number, 0),
            .literal(", "),
            .channel(.green, .number, 0),
            .literal(", "),
            .channel(.blue, .number, 0),
            .literal(", "),
            .channel(.alpha, .percent, 0),
            .literal("%)")
        ],
        isBuiltIn: true
    )

    static let hslaFormat = ColorFormat(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "HSLA",
        tokens: [
            .literal("hsla("),
            .channel(.hue, .number, 0),
            .literal(", "),
            .channel(.saturation, .percent, 0),
            .literal("%, "),
            .channel(.lightness, .percent, 0),
            .literal("%, "),
            .channel(.alpha, .decimal, 1),
            .literal(")")
        ],
        isBuiltIn: true
    )

    static let hsbaFormat = ColorFormat(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "HSBA",
        tokens: [
            .literal("hsba("),
            .channel(.hue, .number, 0),
            .literal(", "),
            .channel(.saturation, .percent, 0),
            .literal("%, "),
            .channel(.brightness, .percent, 0),
            .literal("%, "),
            .channel(.alpha, .decimal, 1),
            .literal(")")
        ],
        isBuiltIn: true
    )

    static let cmykFormat = ColorFormat(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
        name: "CMYK",
        tokens: [
            .literal("cmyk("),
            .channel(.cyan, .percent, 0),
            .literal("%, "),
            .channel(.magenta, .percent, 0),
            .literal("%, "),
            .channel(.yellow, .percent, 0),
            .literal("%, "),
            .channel(.key, .percent, 0),
            .literal("%)")
        ],
        isBuiltIn: true
    )
}
