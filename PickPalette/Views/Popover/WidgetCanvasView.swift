import SwiftUI

/// Canvas renderer — places widgets at absolute positions using ZStack + offset.
struct WidgetCanvasView: View {
    @Bindable var appState: AppState
    var onOpenSettings: () -> Void
    var onEyedropper: () -> Void

    private var layout: PopoverLayoutConfig {
        appState.layoutConfig
    }

    private var enabledWidgets: [WidgetConfig] {
        layout.widgets.filter { $0.isEnabled }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Transparent background to fill the canvas
            Color.clear

            ForEach(enabledWidgets) { widget in
                WidgetFactory.view(
                    for: widget,
                    appState: appState,
                    availableWidth: widget.width ?? 252,
                    onOpenSettings: onOpenSettings,
                    onEyedropper: onEyedropper
                )
                .frame(
                    width: widget.width ?? 252,
                    height: widget.height ?? WidgetSizeConstraints.constraints(for: widget.widgetType).defaultHeight
                )
                .clipped()
                .offset(
                    x: widget.x ?? 0,
                    y: widget.y ?? 0
                )
            }
        }
        .frame(
            width: layout.containerWidth,
            height: layout.containerHeight
        )
        .clipped()
    }
}
