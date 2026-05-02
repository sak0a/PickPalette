import SwiftUI

// MARK: - Widget Type

/// Identifies each distinct widget available in the popover.
enum WidgetType: String, Codable, CaseIterable, Identifiable {
    case colorSwatch
    case colorSpaceTabs
    case hexField
    case spectrumPicker
    case channelSliders
    case recentColors
    case eyedropperButton
    case copyButton
    case settingsButton
    case divider

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .colorSwatch:      return "Color Swatch"
        case .colorSpaceTabs:   return "Color Space Tabs"
        case .hexField:         return "Hex Field"
        case .spectrumPicker:   return "Spectrum Picker"
        case .channelSliders:   return "Channel Sliders"
        case .recentColors:     return "Recent Colors"
        case .eyedropperButton: return "Eyedropper"
        case .copyButton:       return "Copy Button"
        case .settingsButton:   return "Settings"
        case .divider:          return "Divider"
        }
    }

    var icon: String {
        switch self {
        case .colorSwatch:      return "circle.fill"
        case .colorSpaceTabs:   return "slider.horizontal.3"
        case .hexField:         return "number"
        case .spectrumPicker:   return "paintbrush"
        case .channelSliders:   return "slider.vertical.3"
        case .recentColors:     return "clock"
        case .eyedropperButton: return "eyedropper"
        case .copyButton:       return "doc.on.doc"
        case .settingsButton:   return "gearshape"
        case .divider:          return "minus"
        }
    }

    /// Whether multiple instances of this widget are allowed.
    var allowsMultipleInstances: Bool {
        self == .divider || self == .copyButton
    }
}

// MARK: - Widget Config

/// Configuration for a single widget instance in the layout.
struct WidgetConfig: Identifiable, Equatable, Hashable {
    let id: UUID
    var widgetType: WidgetType
    var isEnabled: Bool
    var widthFraction: CGFloat   // 0.1 ... 1.0 (legacy, kept for backward compat)
    var customHeight: CGFloat?
    var formatID: UUID?          // Used by .copyButton to reference a ColorFormat

    // Absolute canvas positioning (nil = not yet migrated)
    var x: CGFloat?
    var y: CGFloat?
    var width: CGFloat?
    var height: CGFloat?

    init(
        id: UUID = UUID(),
        widgetType: WidgetType,
        isEnabled: Bool = true,
        widthFraction: CGFloat = 1.0,
        customHeight: CGFloat? = nil,
        formatID: UUID? = nil,
        x: CGFloat? = nil,
        y: CGFloat? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) {
        self.id = id
        self.widgetType = widgetType
        self.isEnabled = isEnabled
        self.widthFraction = max(0.1, min(1.0, widthFraction))
        self.customHeight = customHeight
        self.formatID = formatID
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - WidgetConfig Codable (with migration from legacy format)

extension WidgetConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, widgetType, isEnabled, widthFraction, span, customHeight, formatID
        case x, y, width, height
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        customHeight = try container.decodeIfPresent(CGFloat.self, forKey: .customHeight)
        formatID = try container.decodeIfPresent(UUID.self, forKey: .formatID)

        // Absolute positioning fields
        x = try container.decodeIfPresent(CGFloat.self, forKey: .x)
        y = try container.decodeIfPresent(CGFloat.self, forKey: .y)
        width = try container.decodeIfPresent(CGFloat.self, forKey: .width)
        height = try container.decodeIfPresent(CGFloat.self, forKey: .height)

        // Widget type migration: copyButton1/copyButton2 → copyButton
        let rawType = try container.decode(String.self, forKey: .widgetType)
        switch rawType {
        case "copyButton1":
            widgetType = .copyButton
            if formatID == nil {
                formatID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")! // hexFormat
            }
        case "copyButton2":
            widgetType = .copyButton
            if formatID == nil {
                formatID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")! // rgbaFormat
            }
        default:
            widgetType = WidgetType(rawValue: rawType) ?? .divider
        }

        // Width fraction migration: widthFraction (new) vs span string (old)
        if let fraction = try container.decodeIfPresent(CGFloat.self, forKey: .widthFraction) {
            widthFraction = max(0.1, min(1.0, fraction))
        } else if let spanString = try container.decodeIfPresent(String.self, forKey: .span) {
            switch spanString {
            case "full":  widthFraction = 1.0
            case "half":  widthFraction = 0.5
            case "third": widthFraction = 1.0 / 3.0
            default:      widthFraction = 1.0
            }
        } else {
            widthFraction = 1.0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(widgetType, forKey: .widgetType)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(widthFraction, forKey: .widthFraction)
        try container.encodeIfPresent(customHeight, forKey: .customHeight)
        try container.encodeIfPresent(formatID, forKey: .formatID)
        try container.encodeIfPresent(x, forKey: .x)
        try container.encodeIfPresent(y, forKey: .y)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
    }
}

// MARK: - Widget Size Constraints

/// Sizing constraints for each widget type.
struct WidgetSizeConstraints {
    var minWidth: CGFloat
    var minHeight: CGFloat
    var defaultWidth: CGFloat
    var defaultHeight: CGFloat
    var maxHeight: CGFloat?
    var isHeightResizable: Bool
    var isFixedSize: Bool

    static func constraints(for type: WidgetType) -> WidgetSizeConstraints {
        switch type {
        case .colorSwatch:
            return WidgetSizeConstraints(minWidth: 32, minHeight: 32, defaultWidth: 52, defaultHeight: 76, maxHeight: nil, isHeightResizable: true, isFixedSize: false)
        case .colorSpaceTabs:
            return WidgetSizeConstraints(minWidth: 100, minHeight: 34, defaultWidth: 192, defaultHeight: 34, maxHeight: 34, isHeightResizable: false, isFixedSize: false)
        case .hexField:
            return WidgetSizeConstraints(minWidth: 100, minHeight: 28, defaultWidth: 252, defaultHeight: 28, maxHeight: 28, isHeightResizable: false, isFixedSize: false)
        case .spectrumPicker:
            return WidgetSizeConstraints(minWidth: 80, minHeight: 80, defaultWidth: 252, defaultHeight: 170, maxHeight: 400, isHeightResizable: true, isFixedSize: false)
        case .channelSliders:
            return WidgetSizeConstraints(minWidth: 120, minHeight: 106, defaultWidth: 252, defaultHeight: 106, maxHeight: nil, isHeightResizable: false, isFixedSize: false)
        case .recentColors:
            return WidgetSizeConstraints(minWidth: 60, minHeight: 28, defaultWidth: 252, defaultHeight: 28, maxHeight: nil, isHeightResizable: false, isFixedSize: false)
        case .eyedropperButton, .settingsButton:
            return WidgetSizeConstraints(minWidth: 28, minHeight: 28, defaultWidth: 28, defaultHeight: 28, maxHeight: 28, isHeightResizable: false, isFixedSize: true)
        case .copyButton:
            return WidgetSizeConstraints(minWidth: 60, minHeight: 28, defaultWidth: 80, defaultHeight: 28, maxHeight: 28, isHeightResizable: false, isFixedSize: false)
        case .divider:
            return WidgetSizeConstraints(minWidth: 20, minHeight: 1, defaultWidth: 252, defaultHeight: 1, maxHeight: 1, isHeightResizable: false, isFixedSize: false)
        }
    }
}

// MARK: - Popover Layout Config

/// Complete serializable layout configuration for the popover.
struct PopoverLayoutConfig: Codable, Equatable {
    var name: String
    var widgets: [WidgetConfig]
    var containerWidth: CGFloat
    var containerHeight: CGFloat
    var gridSpacing: CGFloat
    var edgePadding: CGFloat
    var dotGridSpacing: CGFloat

    init(
        name: String = "Custom",
        widgets: [WidgetConfig] = [],
        containerWidth: CGFloat = 280,
        containerHeight: CGFloat = 400,
        gridSpacing: CGFloat = 0,
        edgePadding: CGFloat = 14,
        dotGridSpacing: CGFloat = 20
    ) {
        self.name = name
        self.widgets = widgets
        self.containerWidth = containerWidth
        self.containerHeight = containerHeight
        self.gridSpacing = gridSpacing
        self.edgePadding = edgePadding
        self.dotGridSpacing = dotGridSpacing
    }

    // Custom Codable to handle missing fields in old JSON
    private enum CodingKeys: String, CodingKey {
        case name, widgets, containerWidth, containerHeight, gridSpacing, edgePadding, dotGridSpacing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        widgets = try container.decode([WidgetConfig].self, forKey: .widgets)
        containerWidth = try container.decode(CGFloat.self, forKey: .containerWidth)
        containerHeight = try container.decodeIfPresent(CGFloat.self, forKey: .containerHeight) ?? 400
        gridSpacing = try container.decode(CGFloat.self, forKey: .gridSpacing)
        edgePadding = try container.decode(CGFloat.self, forKey: .edgePadding)
        dotGridSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .dotGridSpacing) ?? 20
    }
}

// MARK: - Migration: Flexbox → Absolute Positions

extension PopoverLayoutConfig {

    /// Whether any widget still needs migration to absolute positions.
    var needsAbsoluteMigration: Bool {
        widgets.contains { $0.x == nil }
    }

    /// Converts widthFraction-based layout into absolute x/y/width/height positions.
    /// Produces identical visual output to the old flexbox row-wrapping renderer.
    mutating func migrateToAbsolute() {
        let padding = edgePadding
        let innerWidth = containerWidth - 2 * padding
        let rowGap: CGFloat = gridSpacing

        // Build rows (same logic as old WidgetGridView.buildRows)
        var rows: [[Int]] = []    // indices into widgets
        var currentRow: [Int] = []
        var currentFraction: CGFloat = 0

        for i in widgets.indices {
            let fraction = widgets[i].widthFraction
            let isFullOrDivider = fraction >= 1.0 || widgets[i].widgetType == .divider

            if isFullOrDivider {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                    currentFraction = 0
                }
                rows.append([i])
            } else if currentFraction + fraction > 1.001 {
                rows.append(currentRow)
                currentRow = [i]
                currentFraction = fraction
            } else {
                currentRow.append(i)
                currentFraction += fraction
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        // Assign absolute positions
        var cursorY: CGFloat = padding
        let cellGap: CGFloat = 8  // HStack spacing in old renderer

        for row in rows {
            let isSingleFull = row.count == 1 &&
                (widgets[row[0]].widthFraction >= 1.0 || widgets[row[0]].widgetType == .divider)

            var rowHeight: CGFloat = 0

            if isSingleFull {
                let idx = row[0]
                let constraints = WidgetSizeConstraints.constraints(for: widgets[idx].widgetType)
                let h = widgets[idx].customHeight ?? constraints.defaultHeight

                widgets[idx].x = padding
                widgets[idx].y = cursorY
                widgets[idx].width = innerWidth
                widgets[idx].height = h

                rowHeight = h
            } else {
                let gaps = CGFloat(max(0, row.count - 1)) * cellGap
                let totalFraction = row.reduce(CGFloat(0)) { $0 + widgets[$1].widthFraction }
                let usableWidth = innerWidth - gaps

                var cursorX: CGFloat = padding

                for idx in row {
                    let constraints = WidgetSizeConstraints.constraints(for: widgets[idx].widgetType)
                    let w = usableWidth * (widgets[idx].widthFraction / totalFraction)
                    let h = widgets[idx].customHeight ?? constraints.defaultHeight

                    widgets[idx].x = cursorX
                    widgets[idx].y = cursorY
                    widgets[idx].width = w
                    widgets[idx].height = h

                    cursorX += w + cellGap
                    rowHeight = max(rowHeight, h)
                }
            }

            cursorY += rowHeight + rowGap
        }

        // Set container height to fit content + bottom padding
        containerHeight = cursorY + padding
    }
}

// MARK: - Layout Presets

extension PopoverLayoutConfig {

    private static let hexFormatID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let rgbaFormatID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    /// Creates the Vertical preset with absolute positions.
    static var verticalPreset: PopoverLayoutConfig {
        var config = PopoverLayoutConfig(
            name: "Vertical",
            widgets: [
                WidgetConfig(widgetType: .colorSwatch, widthFraction: 0.5),
                WidgetConfig(widgetType: .colorSpaceTabs, widthFraction: 0.5),
                WidgetConfig(widgetType: .hexField),
                WidgetConfig(widgetType: .divider),
                WidgetConfig(widgetType: .spectrumPicker, customHeight: 170),
                WidgetConfig(widgetType: .channelSliders),
                WidgetConfig(widgetType: .recentColors),
                WidgetConfig(widgetType: .divider),
                WidgetConfig(widgetType: .eyedropperButton, widthFraction: 0.25),
                WidgetConfig(widgetType: .copyButton, widthFraction: 0.25, formatID: hexFormatID),
                WidgetConfig(widgetType: .copyButton, widthFraction: 0.25, formatID: rgbaFormatID),
                WidgetConfig(widgetType: .settingsButton, widthFraction: 0.25),
            ],
            containerWidth: 280
        )
        config.migrateToAbsolute()
        return config
    }

    /// Creates the Horizontal preset with absolute positions.
    static var horizontalPreset: PopoverLayoutConfig {
        var config = PopoverLayoutConfig(
            name: "Horizontal",
            widgets: [
                WidgetConfig(widgetType: .colorSwatch, widthFraction: 0.5),
                WidgetConfig(widgetType: .colorSpaceTabs, widthFraction: 0.5),
                WidgetConfig(widgetType: .hexField),
                WidgetConfig(widgetType: .divider),
                WidgetConfig(widgetType: .spectrumPicker, widthFraction: 0.5, customHeight: 106),
                WidgetConfig(widgetType: .channelSliders, widthFraction: 0.5),
                WidgetConfig(widgetType: .recentColors),
                WidgetConfig(widgetType: .divider),
                WidgetConfig(widgetType: .eyedropperButton, widthFraction: 0.25),
                WidgetConfig(widgetType: .copyButton, widthFraction: 0.25, formatID: hexFormatID),
                WidgetConfig(widgetType: .copyButton, widthFraction: 0.25, formatID: rgbaFormatID),
                WidgetConfig(widgetType: .settingsButton, widthFraction: 0.25),
            ],
            containerWidth: 420
        )
        config.migrateToAbsolute()
        return config
    }

    /// Creates the Compact preset with absolute positions.
    static var compactPreset: PopoverLayoutConfig {
        var config = PopoverLayoutConfig(
            name: "Compact",
            widgets: [
                WidgetConfig(widgetType: .colorSwatch, widthFraction: 0.5),
                WidgetConfig(widgetType: .hexField, widthFraction: 0.5),
                WidgetConfig(widgetType: .eyedropperButton, widthFraction: 1.0 / 3.0),
                WidgetConfig(widgetType: .copyButton, widthFraction: 1.0 / 3.0, formatID: hexFormatID),
                WidgetConfig(widgetType: .settingsButton, widthFraction: 1.0 / 3.0),
            ],
            containerWidth: 240
        )
        config.migrateToAbsolute()
        return config
    }

    static let presets: [PopoverLayoutConfig] = [
        verticalPreset, horizontalPreset, compactPreset
    ]
}
