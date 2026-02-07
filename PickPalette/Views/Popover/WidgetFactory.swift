import SwiftUI

/// Factory that builds SwiftUI views for each widget type.
enum WidgetFactory {

    /// Build the SwiftUI view for a given widget config.
    @ViewBuilder
    static func view(
        for config: WidgetConfig,
        appState: AppState,
        availableWidth: CGFloat,
        onOpenSettings: @escaping () -> Void,
        onEyedropper: @escaping () -> Void
    ) -> some View {
        let constraints = WidgetSizeConstraints.constraints(for: config.widgetType)
        let height = config.customHeight ?? constraints.defaultHeight

        switch config.widgetType {
        case .colorSwatch:
            WidgetColorSwatch(appState: appState, size: min(availableWidth, height), shape: config.swatchShape ?? .circle)

        case .colorSpaceTabs:
            let spaces = config.enabledSpaces?.compactMap { ColorSpaceGroup(rawValue: $0) }
            let orient: Axis = (config.tabOrientation ?? .horizontal) == .vertical ? .vertical : .horizontal
            WidgetColorSpaceTabs(appState: appState, height: height, enabledSpaces: spaces, orientation: orient)

        case .hexField:
            WidgetHexField(appState: appState, height: height)

        case .colorSpaceField:
            WidgetColorSpaceField(appState: appState, height: height)

        case .spectrumPicker:
            SpectrumPickerView(
                appState: appState,
                width: availableWidth,
                height: height
            )

        case .channelSliders:
            ColorSlidersView(appState: appState)

        case .recentColors:
            RecentColorsView(appState: appState, width: availableWidth, height: height)

        case .eyedropperButton:
            ToolbarButton(icon: "eyedropper", tooltip: "Pick color from screen", width: availableWidth, height: height) {
                onEyedropper()
            }

        case .copyButton:
            let formatID = config.formatID ?? ColorFormat.hexFormat.id
            let format = appState.formats.first(where: { $0.id == formatID }) ?? ColorFormat.hexFormat
            CopyFormatButton(format: format, width: availableWidth, height: height) {
                appState.copyColor(format: format)
                appState.addToRecent(appState.currentColor)
            }

        case .settingsButton:
            ToolbarButton(icon: "gearshape", tooltip: "Settings", width: availableWidth, height: height) {
                onOpenSettings()
            }

        case .divider:
            Divider()
                .opacity(0.5)
        }
    }
}
