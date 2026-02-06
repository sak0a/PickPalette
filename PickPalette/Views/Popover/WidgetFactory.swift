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
            WidgetColorSwatch(appState: appState)

        case .colorSpaceTabs:
            WidgetColorSpaceTabs(appState: appState)

        case .hexField:
            WidgetHexField(appState: appState)

        case .spectrumPicker:
            SpectrumPickerView(
                appState: appState,
                width: availableWidth,
                height: height
            )

        case .channelSliders:
            ColorSlidersView(appState: appState)

        case .recentColors:
            RecentColorsView(appState: appState)

        case .eyedropperButton:
            ToolbarButton(icon: "eyedropper", tooltip: "Pick color from screen") {
                onEyedropper()
            }

        case .copyButton:
            let formatID = config.formatID ?? ColorFormat.hexFormat.id
            let format = appState.formats.first(where: { $0.id == formatID }) ?? ColorFormat.hexFormat
            CopyFormatButton(format: format) {
                appState.copyColor(format: format)
                appState.addToRecent(appState.currentColor)
            }

        case .settingsButton:
            ToolbarButton(icon: "gearshape", tooltip: "Settings") {
                onOpenSettings()
            }

        case .divider:
            Divider()
                .opacity(0.5)
        }
    }
}
