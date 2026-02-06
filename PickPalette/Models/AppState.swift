import SwiftUI
import AppKit
import Carbon

/// Observable central state for the entire app.
@Observable
final class AppState {
    // Current color being edited
    var currentColor: ColorModel = .defaultColor

    // Active color space in the popover
    var activeColorSpace: ColorSpaceGroup = .rgb

    // Formats
    var formats: [ColorFormat] = ColorFormat.builtInFormats
    var defaultFormatID: UUID = ColorFormat.hexFormat.id

    // Recent colors
    var recentColors: [ColorModel] = []

    // Palettes
    var palettes: [ColorPalette] = []

    // Settings
    var showHUDAfterPick: Bool = true
    var appearance: AppearanceMode = .system
    var launchAtLogin: Bool = false
    var compactMode: Bool = false
    var useGlassStyle: Bool = true
    var popoverLayout: PopoverLayout = .vertical
    var hotkeyKeyCode: UInt32 = 0x08   // 'C' key
    var hotkeyModifiers: UInt32 = UInt32(optionKey | shiftKey) // Option+Shift

    // Popover element visibility (legacy — superseded by layoutConfig)
    var showColorSwatch: Bool = true
    var showColorSpaceTabs: Bool = true
    var showHexField: Bool = true
    var showSpectrumPicker: Bool = true
    var showSliders: Bool = true
    var showRecentColors: Bool = true

    // Configurable color space tabs
    var enabledColorSpaces: [ColorSpaceGroup] = [.hsl, .hsb, .rgb, .cmyk]

    // Widget-based layout configuration
    var layoutConfig: PopoverLayoutConfig = .verticalPreset

    // UI state
    var showCopiedFeedback: Bool = false
    var copiedFormatName: String = ""

    // MARK: - Computed

    var defaultFormat: ColorFormat {
        formats.first(where: { $0.id == defaultFormatID }) ?? ColorFormat.hexFormat
    }

    /// Effective glass mode honors the app toggle and the system transparency accessibility setting.
    var effectiveGlassStyle: Bool {
        useGlassStyle && !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }

    // MARK: - Actions

    func copyColor(format: ColorFormat? = nil) {
        let fmt = format ?? defaultFormat
        let string = fmt.format(color: currentColor)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)

        // Also put NSColor on the pasteboard for native compatibility
        let nsColor = currentColor.nsColor
        nsColor.write(to: pasteboard)

        copiedFormatName = fmt.name
        showCopiedFeedback = true

        // Auto-dismiss feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showCopiedFeedback = false
        }
    }

    func addToRecent(_ color: ColorModel) {
        // Remove duplicates using tolerance-based comparison to handle float precision
        recentColors.removeAll { existing in
            abs(existing.red - color.red) < 0.005 &&
            abs(existing.green - color.green) < 0.005 &&
            abs(existing.blue - color.blue) < 0.005 &&
            abs(existing.alpha - color.alpha) < 0.005
        }
        recentColors.insert(color, at: 0)
        if recentColors.count > 20 {
            recentColors = Array(recentColors.prefix(20))
        }
        save()
    }

    func setColor(_ color: ColorModel) {
        currentColor = color
    }

    func pickFromScreen() {
        NSColorSampler().show { [weak self] selectedColor in
            guard let self, let selectedColor else { return }
            let srgb = selectedColor.usingColorSpace(.sRGB) ?? selectedColor
            let model = ColorModel(nsColor: srgb)
            DispatchQueue.main.async {
                self.currentColor = model
                self.addToRecent(model)
                self.copyColor()
            }
        }
    }

    // MARK: - Persistence

    private static let stateURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PickPalette", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }()

    func save() {
        let data = PersistentState(
            recentColors: recentColors,
            palettes: palettes,
            customFormats: formats.filter { !$0.isBuiltIn },
            defaultFormatID: defaultFormatID,
            showHUDAfterPick: showHUDAfterPick,
            appearance: appearance,
            launchAtLogin: launchAtLogin,
            compactMode: compactMode,
            useGlassStyle: useGlassStyle,
            hotkeyKeyCode: hotkeyKeyCode,
            hotkeyModifiers: hotkeyModifiers,
            showColorSwatch: showColorSwatch,
            showColorSpaceTabs: showColorSpaceTabs,
            showHexField: showHexField,
            showSpectrumPicker: showSpectrumPicker,
            showSliders: showSliders,
            showRecentColors: showRecentColors,
            popoverLayout: popoverLayout,
            layoutConfig: layoutConfig,
            enabledColorSpaces: enabledColorSpaces
        )
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: Self.stateURL, options: .atomic)
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: Self.stateURL),
              let state = try? JSONDecoder().decode(PersistentState.self, from: data) else { return }
        recentColors = state.recentColors
        palettes = state.palettes
        formats = ColorFormat.builtInFormats + state.customFormats
        defaultFormatID = state.defaultFormatID
        showHUDAfterPick = state.showHUDAfterPick
        appearance = state.appearance
        launchAtLogin = state.launchAtLogin
        compactMode = state.compactMode ?? false
        useGlassStyle = state.useGlassStyle ?? true
        if let kc = state.hotkeyKeyCode { hotkeyKeyCode = kc }
        if let mods = state.hotkeyModifiers { hotkeyModifiers = mods }
        showColorSwatch = state.showColorSwatch ?? true
        showColorSpaceTabs = state.showColorSpaceTabs ?? true
        showHexField = state.showHexField ?? true
        showSpectrumPicker = state.showSpectrumPicker ?? true
        showSliders = state.showSliders ?? true
        showRecentColors = state.showRecentColors ?? true
        popoverLayout = state.popoverLayout ?? .vertical
        if let ecs = state.enabledColorSpaces, !ecs.isEmpty { enabledColorSpaces = ecs }

        // Widget layout config — use saved or migrate from legacy fields
        if let lc = state.layoutConfig {
            layoutConfig = lc
        } else {
            layoutConfig = Self.migrateFromLegacy(state)
        }

        // Auto-migrate to absolute positions if needed
        if layoutConfig.needsAbsoluteMigration {
            layoutConfig.migrateToAbsolute()
            save()
        }
    }

    /// Build a PopoverLayoutConfig from legacy show/hide booleans.
    private static func migrateFromLegacy(_ state: PersistentState) -> PopoverLayoutConfig {
        let isHorizontal = state.popoverLayout == .horizontal
        let isCompact = state.compactMode == true

        if isCompact {
            return .compactPreset
        }

        var base = isHorizontal ? PopoverLayoutConfig.horizontalPreset : PopoverLayoutConfig.verticalPreset

        // Apply legacy visibility toggles
        for i in base.widgets.indices {
            switch base.widgets[i].widgetType {
            case .colorSwatch:      base.widgets[i].isEnabled = state.showColorSwatch ?? true
            case .colorSpaceTabs:   base.widgets[i].isEnabled = state.showColorSpaceTabs ?? true
            case .hexField:         base.widgets[i].isEnabled = state.showHexField ?? true
            case .spectrumPicker:   base.widgets[i].isEnabled = state.showSpectrumPicker ?? true
            case .channelSliders:   base.widgets[i].isEnabled = state.showSliders ?? true
            case .recentColors:     base.widgets[i].isEnabled = state.showRecentColors ?? true
            default: break
            }
        }

        return base
    }
}

// MARK: - Persistent State

private struct PersistentState: Codable {
    var recentColors: [ColorModel]
    var palettes: [ColorPalette]
    var customFormats: [ColorFormat]
    var defaultFormatID: UUID
    var showHUDAfterPick: Bool
    var appearance: AppearanceMode
    var launchAtLogin: Bool
    var compactMode: Bool?
    var useGlassStyle: Bool?
    var hotkeyKeyCode: UInt32?
    var hotkeyModifiers: UInt32?
    var copyButton1FormatID: UUID?
    var copyButton2FormatID: UUID?
    var showColorSwatch: Bool?
    var showColorSpaceTabs: Bool?
    var showHexField: Bool?
    var showSpectrumPicker: Bool?
    var showSliders: Bool?
    var showRecentColors: Bool?
    var popoverLayout: PopoverLayout?
    var layoutConfig: PopoverLayoutConfig?
    var enabledColorSpaces: [ColorSpaceGroup]?
}

// MARK: - Supporting Types

enum PopoverLayout: String, Codable, CaseIterable {
    case vertical, horizontal

    var displayName: String {
        switch self {
        case .vertical: return "Vertical"
        case .horizontal: return "Horizontal"
        }
    }
}

enum AppearanceMode: String, Codable, CaseIterable {
    case system, light, dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    var colorSchemeOverride: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct ColorPalette: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var colors: [ColorModel]

    init(id: UUID = UUID(), name: String, colors: [ColorModel] = []) {
        self.id = id
        self.name = name
        self.colors = colors
    }
}
