import SwiftUI

/// Right-side inspector panel for the layout editor.
/// Shows canvas settings when no widget is selected, or widget properties when one is selected.
struct EditorInspectorView: View {
    @Bindable var appState: AppState
    @Binding var selectedWidgetID: UUID?
    @Binding var dotGridSpacing: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var selectedWidget: WidgetConfig? {
        guard let id = selectedWidgetID else { return nil }
        return appState.layoutConfig.widgets.first { $0.id == id }
    }

    private var selectedIndex: Int? {
        guard let id = selectedWidgetID else { return nil }
        return appState.layoutConfig.widgets.firstIndex { $0.id == id }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                if let widget = selectedWidget, let index = selectedIndex {
                    widgetInspector(widget: widget, index: index)
                } else {
                    canvasInspector
                }
            }
            .padding(12)
        }
        .frame(width: 180)
        .background(colorScheme == .dark ? Color(white: 0.10) : Color(white: 0.95))
    }

    // MARK: - Canvas Inspector

    private var canvasInspector: some View {
        VStack(spacing: 14) {
            inspectorHeader("Canvas")

            inspectorSection("Size") {
                numberField(label: "Width", value: Binding(
                    get: { appState.layoutConfig.containerWidth },
                    set: { appState.layoutConfig.containerWidth = clamp($0, 100, 800) }
                ))
                numberField(label: "Height", value: Binding(
                    get: { appState.layoutConfig.containerHeight },
                    set: { appState.layoutConfig.containerHeight = clamp($0, 100, 800) }
                ))
            }

            inspectorSection("Grid") {
                HStack(spacing: 6) {
                    Text("Spacing")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(dotGridSpacing))pt")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $dotGridSpacing,
                    in: 10...80,
                    step: 5
                )
                .controlSize(.small)
                .onChange(of: dotGridSpacing) { _, newValue in
                    appState.layoutConfig.dotGridSpacing = newValue
                    appState.save()
                }
            }
        }
    }

    // MARK: - Widget Inspector

    private func widgetInspector(widget: WidgetConfig, index: Int) -> some View {
        VStack(spacing: 14) {
            inspectorHeader(widget.widgetType.displayName)

            inspectorSection("Position") {
                numberField(label: "X", value: Binding(
                    get: { appState.layoutConfig.widgets[safe: index]?.x ?? 0 },
                    set: { if index < appState.layoutConfig.widgets.count { appState.layoutConfig.widgets[index].x = $0 } }
                ))
                numberField(label: "Y", value: Binding(
                    get: { appState.layoutConfig.widgets[safe: index]?.y ?? 0 },
                    set: { if index < appState.layoutConfig.widgets.count { appState.layoutConfig.widgets[index].y = $0 } }
                ))
            }

            inspectorSection("Size") {
                let constraints = WidgetSizeConstraints.constraints(for: widget.widgetType)
                numberField(label: "W", value: Binding(
                    get: { appState.layoutConfig.widgets[safe: index]?.width ?? constraints.defaultWidth },
                    set: {
                        if index < appState.layoutConfig.widgets.count {
                            appState.layoutConfig.widgets[index].width = max(constraints.minWidth, $0)
                        }
                    }
                ))
                numberField(label: "H", value: Binding(
                    get: { appState.layoutConfig.widgets[safe: index]?.height ?? constraints.defaultHeight },
                    set: {
                        if index < appState.layoutConfig.widgets.count {
                            let clamped = max(constraints.minHeight, constraints.maxHeight.map { min($0, $0) } ?? $0)
                            appState.layoutConfig.widgets[index].height = max(constraints.minHeight, min(clamped, $0))
                        }
                    }
                ))
            }

            inspectorSection("Visibility") {
                Toggle(isOn: Binding(
                    get: { appState.layoutConfig.widgets[safe: index]?.isEnabled ?? true },
                    set: {
                        if index < appState.layoutConfig.widgets.count {
                            appState.layoutConfig.widgets[index].isEnabled = $0
                            appState.save()
                        }
                    }
                )) {
                    Text("Enabled")
                        .font(.system(size: 10))
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            // Copy button format picker
            if widget.widgetType == .copyButton {
                inspectorSection("Format") {
                    Picker("", selection: Binding(
                        get: { appState.layoutConfig.widgets[safe: index]?.formatID ?? UUID() },
                        set: {
                            if index < appState.layoutConfig.widgets.count {
                                appState.layoutConfig.widgets[index].formatID = $0
                                appState.save()
                            }
                        }
                    )) {
                        ForEach(appState.formats) { format in
                            Text(format.name).tag(format.id)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
            }

            // Recent colors settings
            if widget.widgetType == .recentColors {
                inspectorSection("Recent Colors") {
                    HStack(spacing: 4) {
                        Text("Max")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(appState.maxRecentColors)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(appState.maxRecentColors) },
                            set: {
                                appState.maxRecentColors = Int($0)
                                if appState.recentColors.count > appState.maxRecentColors {
                                    appState.recentColors = Array(appState.recentColors.prefix(appState.maxRecentColors))
                                }
                                appState.save()
                            }
                        ),
                        in: 5...100,
                        step: 5
                    )
                    .controlSize(.small)

                    Toggle(isOn: Binding(
                        get: { appState.recentColorsScrollEnabled },
                        set: {
                            appState.recentColorsScrollEnabled = $0
                            appState.save()
                        }
                    )) {
                        Text("Scrolling")
                            .font(.system(size: 10))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Helpers

    private func inspectorHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private func inspectorSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            content()
        }
    }

    private func numberField(label: String, value: Binding<CGFloat>) -> some View {
        let doubleBinding = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = CGFloat($0) }
        )
        return HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)

            TextField("", value: doubleBinding, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10, design: .monospaced))
                .frame(maxWidth: .infinity)
                .onSubmit {
                    appState.save()
                }

            Stepper("", value: value, step: 1)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    private func clamp(_ value: CGFloat, _ min: CGFloat, _ max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}

// Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
