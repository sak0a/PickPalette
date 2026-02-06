import SwiftUI

// MARK: - Add Widget Menu

/// Button that shows a menu of available widget types to add.
/// Places new widgets at absolute canvas positions.
struct AddWidgetMenu: View {
    @Bindable var appState: AppState
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    private var availableTypes: [WidgetType] {
        let existingTypes = Set(appState.layoutConfig.widgets.map(\.widgetType))
        return WidgetType.allCases.filter { type in
            type.allowsMultipleInstances || !existingTypes.contains(type)
        }
    }

    var body: some View {
        Menu {
            ForEach(availableTypes) { type in
                Button {
                    addWidget(type)
                } label: {
                    Label(type.displayName, systemImage: type.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                Text("Add")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        PopoverTheme.subtleFill(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        )
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        PopoverTheme.subtleStroke(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func addWidget(_ type: WidgetType) {
        let constraints = WidgetSizeConstraints.constraints(for: type)
        let w = constraints.defaultWidth
        let h = constraints.defaultHeight
        let containerW = appState.layoutConfig.containerWidth
        let containerH = appState.layoutConfig.containerHeight

        // Place at center of canvas
        let x = max(0, (containerW - w) / 2)
        let y = max(0, (containerH - h) / 2)

        var config = WidgetConfig(
            widgetType: type,
            x: x, y: y,
            width: w, height: h
        )
        if type == .copyButton {
            config = WidgetConfig(
                widgetType: type,
                formatID: ColorFormat.hexFormat.id,
                x: x, y: y,
                width: w, height: h
            )
        }
        appState.layoutConfig.widgets.append(config)
        appState.save()
    }
}
