import SwiftUI
import ServiceManagement
import ScreenCaptureKit
import Carbon

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable, Hashable {
    case general
    case appearance
    case layout
    case formats
    case palettes
    case shortcuts
    case license

    var label: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .layout: return "Layout"
        case .formats: return "Formats"
        case .palettes: return "Palettes"
        case .shortcuts: return "Shortcuts"
        case .license: return "License"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .layout: return "rectangle.3.group"
        case .formats: return "textformat"
        case .palettes: return "paintpalette"
        case .shortcuts: return "keyboard"
        case .license: return "doc.text"
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var selectedTab: SettingsTab = .general
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            settingsSidebar
                .frame(width: 160)

            // Divider
            Rectangle()
                .fill(SettingsTheme.dividerColor(
                    useGlassStyle: appState.effectiveGlassStyle,
                    colorScheme: colorScheme
                ))
                .frame(width: 1)

            // Content
            ZStack {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(appState: appState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: 8)),
                            removal: .opacity
                        ))
                case .appearance:
                    AppearanceSettingsView(appState: appState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: 8)),
                            removal: .opacity
                        ))
                case .layout:
                    LayoutSettingsView(appState: appState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: 8)),
                            removal: .opacity
                        ))
                case .formats:
                    FormatsSettingsView(appState: appState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: 8)),
                            removal: .opacity
                        ))
                case .palettes:
                    PalettesSettingsView(appState: appState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: 8)),
                            removal: .opacity
                        ))
                case .shortcuts:
                    ShortcutsSettingsView(appState: appState)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: 8)),
                            removal: .opacity
                        ))
                case .license:
                    LicenseSettingsView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: 8)),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(duration: 0.3, bounce: 0.1), value: selectedTab)
        }
        .frame(width: 600, height: 480)
        .background(SettingsTheme.windowBackground(
            useGlassStyle: appState.effectiveGlassStyle,
            colorScheme: colorScheme
        ))
        .foregroundStyle(SettingsTheme.primaryTextColor(
            useGlassStyle: appState.effectiveGlassStyle,
            colorScheme: colorScheme
        ))
        .environment(\.useGlassStyle, appState.effectiveGlassStyle)
    }

    // MARK: - Sidebar

    @Namespace private var sidebarNamespace

    private var settingsSidebar: some View {
        VStack(spacing: 4) {
            // Title area
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SettingsTheme.secondaryTextColor(
                    useGlassStyle: appState.effectiveGlassStyle,
                    colorScheme: colorScheme
                ))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)

            ForEach(SettingsTab.allCases, id: \.self) { tab in
                GlassSidebarItem(
                    icon: tab.icon,
                    label: tab.label,
                    isSelected: selectedTab == tab,
                    namespace: sidebarNamespace
                ) {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        selectedTab = tab
                    }
                }
            }

            Spacer()

            // Version info
            Text("PickPalette v1.0")
                .font(.system(size: 10))
                .foregroundStyle(SettingsTheme.tertiaryTextColor(
                    useGlassStyle: appState.effectiveGlassStyle,
                    colorScheme: colorScheme
                ))
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 8)
        .background(
            SettingsTheme.sidebarBackground(
                useGlassStyle: appState.effectiveGlassStyle,
                colorScheme: colorScheme
            )
        )
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Bindable var appState: AppState
    @State private var screenCaptureGranted: Bool = false
    @State private var accessibilityGranted: Bool = false

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                GlassSection(title: "Defaults") {
                    VStack(spacing: 12) {
                        GlassPicker(
                            label: "Default Copy Format",
                            selection: $appState.defaultFormatID,
                            options: appState.formats.map { ($0.id, $0.name) }
                        )
                    }
                }

                GlassSection(title: "Behavior") {
                    VStack(spacing: 12) {
                        GlassToggle(
                            label: "Show HUD after picking color",
                            isOn: $appState.showHUDAfterPick
                        )

                        GlassToggle(
                            label: "Launch at Login",
                            isOn: Binding(
                                get: { appState.launchAtLogin },
                                set: { newValue in
                                    appState.launchAtLogin = newValue
                                    do {
                                        if newValue {
                                            try SMAppService.mainApp.register()
                                        } else {
                                            try SMAppService.mainApp.unregister()
                                        }
                                    } catch {
                                        appState.launchAtLogin = !newValue
                                    }
                                }
                            )
                        )
                    }
                }

                GlassSection(title: "Permissions") {
                    VStack(spacing: 10) {
                        PermissionRow(
                            icon: "camera.metering.spot",
                            label: "Screen Recording",
                            description: "Required for the eyedropper tool",
                            isGranted: screenCaptureGranted
                        ) {
                            openSystemPreferences(pane: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
                        }

                        Divider().opacity(0.3)

                        PermissionRow(
                            icon: "hand.raised",
                            label: "Accessibility",
                            description: "Required for global hotkey",
                            isGranted: accessibilityGranted
                        ) {
                            openSystemPreferences(pane: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        // Check accessibility
        accessibilityGranted = AccessibilityHelper.isTrusted

        // Check screen capture
        screenCaptureGranted = CGPreflightScreenCaptureAccess()
    }

    private func openSystemPreferences(pane: String) {
        if let url = URL(string: pane) {
            NSWorkspace.shared.open(url)
        }
    }
}

/// A row showing permission status with an action button.
struct PermissionRow: View {
    let icon: String
    let label: String
    let description: String
    let isGranted: Bool
    let onOpenSettings: () -> Void

    @State private var isHovering = false
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isGranted ? .green : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(isGranted ? .green : .orange)
                }
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(SettingsTheme.tertiaryTextColor(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    ))
            }

            Spacer()

            if !isGranted {
                Button {
                    onOpenSettings()
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isHovering ? .primary : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(SettingsTheme.controlBackground(
                                    useGlassStyle: useGlassStyle,
                                    colorScheme: colorScheme
                                ))
                                .opacity(isHovering ? 1 : 0.6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(.primary.opacity(isHovering ? 0.1 : 0.06), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
            } else {
                Text("Granted")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green.opacity(0.8))
            }
        }
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                GlassSection(title: "Theme") {
                    VStack(spacing: 12) {
                        GlassPicker(
                            label: "Appearance",
                            selection: $appState.appearance,
                            options: AppearanceMode.allCases.map { ($0, $0.displayName) }
                        )

                        GlassToggle(
                            label: "Glass Style",
                            isOn: Binding(
                                get: { appState.useGlassStyle },
                                set: { newValue in
                                    appState.useGlassStyle = newValue
                                    appState.save()
                                }
                            )
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use translucent glass materials for backgrounds. Disable for solid fill colors.")
                            Text("Glass is also disabled when macOS Reduce Transparency is enabled.")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    }
                }

                GlassSection(title: "Color Space Tabs") {
                    VStack(spacing: 8) {
                        Text("Choose which color spaces appear in the popover tabs.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        VStack(spacing: 8) {
                            ForEach([ColorSpaceGroup.hsl, .hsb, .rgb, .cmyk], id: \.self) { space in
                                let isEnabled = appState.enabledColorSpaces.contains(space)
                                let isLast = appState.enabledColorSpaces.count == 1 && isEnabled
                                GlassToggle(
                                    label: space.displayName,
                                    isOn: Binding(
                                        get: { isEnabled },
                                        set: { newValue in
                                            if newValue {
                                                if !appState.enabledColorSpaces.contains(space) {
                                                    appState.enabledColorSpaces.append(space)
                                                }
                                            } else {
                                                // Don't allow removing the last one
                                                guard appState.enabledColorSpaces.count > 1 else { return }
                                                appState.enabledColorSpaces.removeAll { $0 == space }
                                                // If active space was removed, switch to first enabled
                                                if appState.activeColorSpace == space {
                                                    appState.activeColorSpace = appState.enabledColorSpaces.first ?? .rgb
                                                }
                                            }
                                            appState.save()
                                        }
                                    )
                                )
                                .opacity(isLast ? 0.5 : 1.0)
                            }
                        }
                    }
                }

                GlassSection(title: "Info") {
                    Text("Copy button formats are now configured per-widget in the Layout tab or in Edit Mode (right-click the popover).")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .onChange(of: appState.appearance) { _, newValue in
            NSApp.appearance = newValue.nsAppearance
            appState.save()
        }
    }
}

// MARK: - Layout Settings

struct LayoutSettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                // Open Editor button (prominent)
                GlassSection(title: "Canvas Editor") {
                    VStack(spacing: 8) {
                        Text("Use the layout editor to freely position and resize widgets on a canvas. Right-click the popover to open it.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        HStack {
                            GlassButton(icon: "rectangle.3.group", label: "Open Layout Editor") {
                                NotificationCenter.default.post(name: .openLayoutEditor, object: nil)
                            }
                            Spacer()
                        }
                    }
                }

                // Presets
                GlassSection(title: "Presets") {
                    HStack(spacing: 8) {
                        ForEach(PopoverLayoutConfig.presets, id: \.name) { preset in
                            let isActive = appState.layoutConfig.name == preset.name
                                && appState.layoutConfig.containerWidth == preset.containerWidth

                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    appState.layoutConfig = preset
                                    appState.save()
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: presetIcon(for: preset.name))
                                        .font(.system(size: 16, weight: .medium))
                                    Text(preset.name)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(isActive ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isActive ? Color.accentColor.gradient : Color.primary.opacity(0.04).gradient)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(isActive ? Color.clear : Color.primary.opacity(0.06), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Container size
                GlassSection(title: "Container Size") {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Text("Width")
                                .font(.system(size: 12))

                            Slider(
                                value: $appState.layoutConfig.containerWidth,
                                in: 200...600,
                                step: 5
                            )

                            Text("\(Int(appState.layoutConfig.containerWidth))pt")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                        }

                        HStack(spacing: 10) {
                            Text("Height")
                                .font(.system(size: 12))

                            Slider(
                                value: $appState.layoutConfig.containerHeight,
                                in: 100...800,
                                step: 5
                            )

                            Text("\(Int(appState.layoutConfig.containerHeight))pt")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                }

                // Widgets list (simplified: name, eye toggle, format picker, delete)
                GlassSection(title: "Widgets") {
                    VStack(spacing: 2) {
                        ForEach(Array(appState.layoutConfig.widgets.enumerated()), id: \.element.id) { index, widget in
                            widgetRow(widget, at: index)
                        }
                    }

                    // Add widget
                    addWidgetRow
                }

                // Reset
                GlassSection(title: "Reset") {
                    HStack {
                        GlassButton(icon: "arrow.counterclockwise", label: "Reset to Default") {
                            withAnimation(.spring(duration: 0.3)) {
                                appState.layoutConfig = .verticalPreset
                                appState.save()
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Widget Row

    @ViewBuilder
    private func widgetRow(_ widget: WidgetConfig, at index: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: widget.widgetType.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(widget.isEnabled ? .primary : .tertiary)
                .frame(width: 18)

            Text(widgetDisplayName(widget))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(widget.isEnabled ? .primary : .tertiary)

            Spacer()

            // Format picker (copy buttons only)
            if widget.widgetType == .copyButton {
                widgetFormatPicker(widget, at: index)
            }

            // Eye toggle
            Button {
                appState.layoutConfig.widgets[index].isEnabled.toggle()
                appState.save()
            } label: {
                Image(systemName: widget.isEnabled ? "eye" : "eye.slash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(widget.isEnabled ? Color.secondary : Color.orange)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)

            // Delete
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    appState.layoutConfig.widgets.remove(at: index)
                    appState.save()
                }
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red.opacity(0.6))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.primary.opacity(0.02))
        )
    }

    private func widgetDisplayName(_ widget: WidgetConfig) -> String {
        if widget.widgetType == .copyButton {
            let name = appState.formats.first(where: { $0.id == widget.formatID })?.name ?? "HEX"
            return "Copy \(name)"
        }
        return widget.widgetType.displayName
    }

    private func widgetFormatPicker(_ widget: WidgetConfig, at index: Int) -> some View {
        Menu {
            ForEach(appState.formats) { format in
                Button {
                    appState.layoutConfig.widgets[index].formatID = format.id
                    appState.save()
                } label: {
                    HStack {
                        Text(format.name)
                        if widget.formatID == format.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "textformat")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.primary.opacity(0.04))
                )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Add Widget

    private var addWidgetRow: some View {
        let existingTypes = Set(appState.layoutConfig.widgets.map(\.widgetType))
        let available = WidgetType.allCases.filter { $0.allowsMultipleInstances || !existingTypes.contains($0) }

        return Menu {
            ForEach(available) { type in
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        let constraints = WidgetSizeConstraints.constraints(for: type)
                        let w = constraints.defaultWidth
                        let h = constraints.defaultHeight
                        let containerW = appState.layoutConfig.containerWidth
                        let containerH = appState.layoutConfig.containerHeight
                        let x = max(0, (containerW - w) / 2)
                        let y = max(0, (containerH - h) / 2)

                        var config = WidgetConfig(widgetType: type, x: x, y: y, width: w, height: h)
                        if type == .copyButton {
                            config = WidgetConfig(widgetType: type, formatID: ColorFormat.hexFormat.id, x: x, y: y, width: w, height: h)
                        }
                        appState.layoutConfig.widgets.append(config)
                        appState.save()
                    }
                } label: {
                    Label(type.displayName, systemImage: type.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11, weight: .medium))
                Text("Add Widget")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Color.primary.opacity(0.08),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Helpers

    private func presetIcon(for name: String) -> String {
        switch name {
        case "Vertical": return "rectangle.portrait"
        case "Horizontal": return "rectangle"
        case "Compact": return "rectangle.compress.vertical"
        default: return "rectangle.3.group"
        }
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                GlassSection(title: "Eyedropper") {
                    ShortcutRecorderRow(appState: appState)
                }

                GlassSection(title: "Coming Soon") {
                    Text("Per-format copy shortcuts will be available here in a future update.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - License Settings

struct LicenseSettingsView: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                GlassSection(title: "License") {
                    Text("License management will be available here in a future update.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Formats Settings

struct FormatsSettingsView: View {
    @Bindable var appState: AppState
    @State private var selectedFormatID: UUID?
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Format list
            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    VStack(spacing: 2) {
                        ForEach(appState.formats) { format in
                            GlassListItem(
                                title: format.name,
                                subtitle: format.isBuiltIn ? "Built-in" : nil,
                                isSelected: selectedFormatID == format.id
                            ) {
                                withAnimation(.spring(duration: 0.2)) {
                                    selectedFormatID = format.id
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }

                // Bottom actions
                HStack(spacing: 8) {
                    GlassIconButton(icon: "plus", size: 22) {
                        addFormat()
                    }
                    GlassIconButton(icon: "minus", size: 22) {
                        deleteSelectedFormat()
                    }
                    .opacity(canDeleteSelected ? 1 : 0.3)
                    .disabled(!canDeleteSelected)

                    Spacer()
                }
                .padding(8)
            }
            .frame(width: 170)
            .background(
                SettingsTheme.sidebarBackground(
                    useGlassStyle: useGlassStyle,
                    colorScheme: colorScheme
                )
            )

            Rectangle()
                .fill(SettingsTheme.dividerColor(
                    useGlassStyle: useGlassStyle,
                    colorScheme: colorScheme
                ))
                .frame(width: 1)

            // Format editor
            if let format = selectedFormat {
                FormatEditorView(
                    format: Binding(
                        get: { format },
                        set: { updated in
                            if let idx = appState.formats.firstIndex(where: { $0.id == updated.id }) {
                                appState.formats[idx] = updated
                                appState.save()
                            }
                        }
                    ),
                    previewColor: appState.currentColor,
                    isBuiltIn: format.isBuiltIn
                )
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("Select a format to edit")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var selectedFormat: ColorFormat? {
        appState.formats.first(where: { $0.id == selectedFormatID })
    }

    private var canDeleteSelected: Bool {
        guard let id = selectedFormatID,
              let format = appState.formats.first(where: { $0.id == id }) else { return false }
        return !format.isBuiltIn
    }

    private func addFormat() {
        let newFormat = ColorFormat(name: "Custom Format", tokens: [.literal("#"), .channel(.hex, .number, 0)])
        appState.formats.append(newFormat)
        selectedFormatID = newFormat.id
        appState.save()
    }

    private func deleteSelectedFormat() {
        guard let id = selectedFormatID,
              let format = appState.formats.first(where: { $0.id == id }),
              !format.isBuiltIn else { return }
        withAnimation(.spring(duration: 0.2)) {
            appState.formats.removeAll { $0.id == id }
            selectedFormatID = appState.formats.first?.id
        }
        appState.save()
    }
}

// MARK: - Format Editor

struct FormatEditorView: View {
    @Binding var format: ColorFormat
    let previewColor: ColorModel
    let isBuiltIn: Bool

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                // Name
                GlassSection(title: "Name") {
                    if !isBuiltIn {
                        GlassTextField(text: $format.name, placeholder: "Format Name")
                    } else {
                        Text(format.name)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }

                // Token display
                GlassSection(title: "Format Tokens") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(format.tokens.enumerated()), id: \.offset) { index, token in
                                tokenView(token, at: index)
                            }
                        }
                        .padding(4)
                    }
                }

                // Add token buttons (only for custom formats)
                if !isBuiltIn {
                    GlassSection(title: "Add Token") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(ColorSpaceGroup.allCases, id: \.self) { group in
                                HStack(spacing: 6) {
                                    Text(group.displayName)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 36, alignment: .leading)
                                    ForEach(group.channels, id: \.self) { channel in
                                        GlassTokenButton(label: channel.displayName) {
                                            withAnimation(.spring(duration: 0.2)) {
                                                format.tokens.append(.channel(channel, .number, 0))
                                            }
                                        }
                                    }
                                }
                            }

                            HStack(spacing: 6) {
                                Text("Lit.")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 36, alignment: .leading)
                                ForEach(["(", ")", ", ", " ", "#", "%"], id: \.self) { lit in
                                    GlassTokenButton(label: lit == " " ? "Space" : lit) {
                                        withAnimation(.spring(duration: 0.2)) {
                                            format.tokens.append(.literal(lit))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Live preview
                GlassSection(title: "Preview") {
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(previewColor.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                            )

                        Text(format.format(color: previewColor))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func tokenView(_ token: FormatToken, at index: Int) -> some View {
        HStack(spacing: 2) {
            Text(token.displayLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(tokenColor(for: token).gradient)
                )
                .shadow(color: tokenColor(for: token).opacity(0.3), radius: 3, y: 1)

            if !isBuiltIn {
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        let _ = format.tokens.remove(at: index)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func tokenColor(for token: FormatToken) -> Color {
        switch token {
        case .literal: return .gray
        case .channel(let ch, _, _):
            switch ch.colorSpaceGroup {
            case .rgb: return .blue
            case .hsl: return .purple
            case .hsb: return .orange
            case .cmyk: return .teal
            case .hex: return .green
            }
        }
    }
}

// MARK: - Palettes Settings

struct PalettesSettingsView: View {
    @Bindable var appState: AppState
    @State private var selectedPaletteID: UUID?
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Palette list
            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    VStack(spacing: 2) {
                        ForEach(appState.palettes) { palette in
                            GlassListItem(
                                title: palette.name,
                                subtitle: "\(palette.colors.count) colors",
                                isSelected: selectedPaletteID == palette.id
                            ) {
                                withAnimation(.spring(duration: 0.2)) {
                                    selectedPaletteID = palette.id
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }

                HStack(spacing: 8) {
                    GlassIconButton(icon: "plus", size: 22) {
                        addPalette()
                    }
                    GlassIconButton(icon: "minus", size: 22) {
                        deleteSelectedPalette()
                    }
                    .opacity(selectedPaletteID != nil ? 1 : 0.3)
                    .disabled(selectedPaletteID == nil)

                    Spacer()
                }
                .padding(8)
            }
            .frame(width: 170)
            .background(
                SettingsTheme.sidebarBackground(
                    useGlassStyle: useGlassStyle,
                    colorScheme: colorScheme
                )
            )

            Rectangle()
                .fill(SettingsTheme.dividerColor(
                    useGlassStyle: useGlassStyle,
                    colorScheme: colorScheme
                ))
                .frame(width: 1)

            // Palette detail
            if let palette = selectedPalette {
                PaletteDetailView(
                    palette: Binding(
                        get: { palette },
                        set: { updated in
                            if let idx = appState.palettes.firstIndex(where: { $0.id == updated.id }) {
                                appState.palettes[idx] = updated
                                appState.save()
                            }
                        }
                    ),
                    currentColor: appState.currentColor,
                    onAddCurrent: {
                        if let idx = appState.palettes.firstIndex(where: { $0.id == palette.id }) {
                            appState.palettes[idx].colors.append(appState.currentColor)
                            appState.save()
                        }
                    }
                )
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "paintpalette")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("Select or create a palette")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var selectedPalette: ColorPalette? {
        appState.palettes.first(where: { $0.id == selectedPaletteID })
    }

    private func addPalette() {
        let palette = ColorPalette(name: "New Palette")
        appState.palettes.append(palette)
        withAnimation(.spring(duration: 0.2)) {
            selectedPaletteID = palette.id
        }
        appState.save()
    }

    private func deleteSelectedPalette() {
        guard let id = selectedPaletteID else { return }
        withAnimation(.spring(duration: 0.2)) {
            appState.palettes.removeAll { $0.id == id }
            selectedPaletteID = appState.palettes.first?.id
        }
        appState.save()
    }
}

// MARK: - Palette Detail

struct PaletteDetailView: View {
    @Binding var palette: ColorPalette
    let currentColor: ColorModel
    let onAddCurrent: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                GlassSection(title: "Name") {
                    GlassTextField(text: $palette.name, placeholder: "Palette Name")
                }

                GlassSection(title: "Actions") {
                    HStack(spacing: 8) {
                        GlassButton(icon: "plus.circle", label: "Add Current") {
                            withAnimation(.spring(duration: 0.25)) {
                                onAddCurrent()
                            }
                        }

                        GlassButton(icon: "doc.on.doc", label: "JSON") {
                            exportJSON()
                        }

                        GlassButton(icon: "chevron.left.forwardslash.chevron.right", label: "CSS") {
                            exportCSS()
                        }

                        Spacer()
                    }
                }

                GlassSection(title: "Colors (\(palette.colors.count))") {
                    if palette.colors.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle.dashed")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.quaternary)
                                Text("No colors yet")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 16)
                            Spacer()
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                            ForEach(Array(palette.colors.enumerated()), id: \.offset) { index, color in
                                PaletteColorSwatch(color: color) {
                                    withAnimation(.spring(duration: 0.2)) {
                                        let _ = palette.colors.remove(at: index)
                                    }
                                } onCopy: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(color.hexString, forType: .string)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func exportJSON() {
        let json = palette.colors.map { $0.hexString }
        if let data = try? JSONEncoder().encode(json),
           let string = String(data: data, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    }

    private func exportCSS() {
        let css = palette.colors.enumerated().map { index, color in
            "  --color-\(index + 1): \(color.hexString);"
        }.joined(separator: "\n")
        let output = ":root {\n\(css)\n}"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }
}

// MARK: - Palette Color Swatch

struct PaletteColorSwatch: View {
    let color: ColorModel
    let onRemove: () -> Void
    let onCopy: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.color)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: isHovering ? color.color.opacity(0.4) : .clear, radius: 6)
                .scaleEffect(isHovering ? 1.08 : 1.0)

            Text(color.hexString)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .animation(.spring(duration: 0.2), value: isHovering)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy Hex") { onCopy() }
            Divider()
            Button("Remove", role: .destructive) { onRemove() }
        }
    }
}

// MARK: - Glass Style Environment Key

private struct GlassStyleKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var useGlassStyle: Bool {
        get { self[GlassStyleKey.self] }
        set { self[GlassStyleKey.self] = newValue }
    }
}

private enum SettingsTheme {
    static func windowBackground(useGlassStyle: Bool, colorScheme: ColorScheme) -> AnyShapeStyle {
        if useGlassStyle {
            return AnyShapeStyle(
                colorScheme == .dark
                    ? Color.clear
                    : Color.white.opacity(0.18)
            )
        }
        return AnyShapeStyle(
            colorScheme == .dark
                ? Color(white: 0.10).opacity(0.94)
                : Color.white.opacity(0.84)
        )
    }

    static func sidebarBackground(useGlassStyle: Bool, colorScheme: ColorScheme) -> AnyShapeStyle {
        if useGlassStyle {
            if colorScheme == .dark {
                return AnyShapeStyle(.ultraThinMaterial.opacity(0.56))
            }
            return AnyShapeStyle(.thickMaterial.opacity(0.90))
        }
        return AnyShapeStyle(
            colorScheme == .dark
                ? Color(white: 0.13).opacity(0.90)
                : Color.white.opacity(0.72)
        )
    }

    static func sectionBackground(useGlassStyle: Bool, colorScheme: ColorScheme) -> AnyShapeStyle {
        if useGlassStyle {
            if colorScheme == .dark {
                return AnyShapeStyle(.ultraThinMaterial.opacity(0.64))
            }
            return AnyShapeStyle(.regularMaterial.opacity(0.94))
        }
        return AnyShapeStyle(
            colorScheme == .dark
                ? Color(white: 0.16).opacity(0.92)
                : Color.white.opacity(0.86)
        )
    }

    static func controlBackground(useGlassStyle: Bool, colorScheme: ColorScheme) -> AnyShapeStyle {
        if useGlassStyle {
            if colorScheme == .dark {
                return AnyShapeStyle(.thinMaterial.opacity(0.92))
            }
            return AnyShapeStyle(.thickMaterial.opacity(0.98))
        }
        return AnyShapeStyle(
            colorScheme == .dark
                ? Color(white: 0.20).opacity(0.92)
                : Color.white.opacity(0.92)
        )
    }

    static func dividerColor(useGlassStyle: Bool, colorScheme: ColorScheme) -> Color {
        if useGlassStyle {
            return colorScheme == .dark ? .white.opacity(0.11) : .black.opacity(0.08)
        }
        return colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.10)
    }

    static func primaryTextColor(useGlassStyle: Bool, colorScheme: ColorScheme) -> Color {
        if useGlassStyle {
            return colorScheme == .dark ? .white.opacity(0.93) : .black.opacity(0.84)
        }
        return colorScheme == .dark ? .white.opacity(0.94) : .black.opacity(0.88)
    }

    static func secondaryTextColor(useGlassStyle: Bool, colorScheme: ColorScheme) -> Color {
        if useGlassStyle {
            return colorScheme == .dark ? .white.opacity(0.78) : .black.opacity(0.70)
        }
        return colorScheme == .dark ? .white.opacity(0.80) : .black.opacity(0.74)
    }

    static func tertiaryTextColor(useGlassStyle: Bool, colorScheme: ColorScheme) -> Color {
        if useGlassStyle {
            return colorScheme == .dark ? .white.opacity(0.56) : .black.opacity(0.50)
        }
        return colorScheme == .dark ? .white.opacity(0.58) : .black.opacity(0.56)
    }
}

// MARK: - Reusable Glass Components

/// Glass section card with a title and content.
struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(SettingsTheme.tertiaryTextColor(
                    useGlassStyle: useGlassStyle,
                    colorScheme: colorScheme
                ))
                .tracking(0.5)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SettingsTheme.sectionBackground(
                    useGlassStyle: useGlassStyle,
                    colorScheme: colorScheme
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}

/// Custom toggle with animated capsule track.
struct GlassToggle: View {
    let label: String
    @Binding var isOn: Bool

    @State private var isHovering = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))

            Spacer()

            Button {
                withAnimation(.spring(duration: 0.25, bounce: 0.2)) {
                    isOn.toggle()
                }
            } label: {
                Capsule()
                    .fill(isOn ? Color.accentColor : Color.primary.opacity(0.12))
                    .frame(width: 34, height: 20)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                            .padding(.horizontal, 2)
                    }
                    .scaleEffect(isHovering ? 1.05 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .animation(.spring(duration: 0.2), value: isHovering)
        }
    }
}

/// Custom picker row with a dropdown menu.
struct GlassPicker<T: Hashable>: View {
    let label: String
    @Binding var selection: T
    let options: [(T, String)]

    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))

            Spacer()

            Menu {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            selection = option.0
                        }
                    } label: {
                        HStack {
                            Text(option.1)
                            if selection == option.0 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(options.first(where: { $0.0 == selection })?.1 ?? "")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(SettingsTheme.controlBackground(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        ))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
            .menuStyle(.borderlessButton)
        }
    }
}

/// Glass-styled text field.
struct GlassTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    var isMonospaced: Bool = false

    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium, design: isMonospaced ? .monospaced : .default))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(SettingsTheme.controlBackground(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            )
    }
}

/// Glass button with icon and label.
struct GlassButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isHovering ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(SettingsTheme.controlBackground(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    ))
                    .opacity(isHovering ? 1 : 0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.primary.opacity(isHovering ? 0.12 : 0.06), lineWidth: 0.5)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

/// Small icon-only glass button.
struct GlassIconButton: View {
    let icon: String
    var size: CGFloat = 24
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(SettingsTheme.controlBackground(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        ))
                        .opacity(isHovering ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

/// Small token button for the format editor.
struct GlassTokenButton: View {
    let label: String
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SettingsTheme.controlBackground(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        ))
                        .opacity(isHovering ? 1 : 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.primary.opacity(isHovering ? 0.1 : 0.05), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

/// Sidebar navigation item with icon and label.
struct GlassSidebarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : SettingsTheme.secondaryTextColor(
                                useGlassStyle: useGlassStyle,
                                colorScheme: colorScheme
                            )
                    )
                    .frame(width: 20)

                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : (isHovering
                                ? Color.primary
                                : SettingsTheme.secondaryTextColor(
                                    useGlassStyle: useGlassStyle,
                                    colorScheme: colorScheme
                                ))
                    )

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.accentColor.gradient)
                        .matchedGeometryEffect(id: "sidebarSelection", in: namespace)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 4, y: 1)
                } else if isHovering {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(.primary.opacity(0.06))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

/// List item for format/palette lists.
struct GlassListItem: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer()

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(SettingsTheme.tertiaryTextColor(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        ))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.primary.opacity(0.05))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(SettingsTheme.controlBackground(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    ))
                    .opacity(isSelected ? 1 : (isHovering ? 0.5 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.primary.opacity(isSelected ? 0.08 : 0), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Shortcut Recorder

/// Interactive row: click to record a new global keyboard shortcut.
struct ShortcutRecorderRow: View {
    @Bindable var appState: AppState
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            Text("Pick color from anywhere")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            if isRecording {
                HStack(spacing: 6) {
                    Text("Press shortcut…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))

                    Button {
                        isRecording = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.accentColor.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
                .background {
                    ShortcutCaptureView(
                        isRecording: $isRecording,
                        onCapture: { keyCode, modifiers in
                            appState.hotkeyKeyCode = keyCode
                            appState.hotkeyModifiers = modifiers
                            appState.save()
                            // Re-register with new shortcut
                            GlobalHotkeyManager.shared.register(
                                keyCode: keyCode,
                                modifiers: modifiers,
                                handler: {
                                    NotificationCenter.default.post(name: .pickColorHotkey, object: nil)
                                }
                            )
                            isRecording = false
                        }
                    )
                }
            } else {
                Button {
                    isRecording = true
                } label: {
                    let display = shortcutKeyCaps
                    HStack(spacing: 3) {
                        ForEach(display, id: \.self) { cap in
                            KeyCapView(key: cap)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Click to change shortcut")
            }
        }
    }

    private var shortcutKeyCaps: [String] {
        var caps = GlobalHotkeyManager.modifierSymbols(for: appState.hotkeyModifiers)
        caps.append(GlobalHotkeyManager.keyName(for: appState.hotkeyKeyCode))
        return caps
    }
}

/// NSViewRepresentable that captures key events when recording.
struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onCapture = onCapture
        view.onCancel = { isRecording = false }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        if isRecording {
            // Ensure the view can receive key events
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

/// AppKit view that becomes first responder and captures key-down events.
final class ShortcutCaptureNSView: NSView {
    var onCapture: ((UInt32, UInt32) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        // Require at least one modifier key
        let modFlags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !modFlags.isEmpty else { return }

        let carbonMods = GlobalHotkeyManager.carbonModifiers(from: modFlags)
        onCapture?(UInt32(event.keyCode), carbonMods)
    }

    override func flagsChanged(with event: NSEvent) {
        // Ignore standalone modifier presses
    }
}

/// Notification names.
extension Notification.Name {
    static let pickColorHotkey = Notification.Name("PickPalette.pickColorHotkey")
    static let openLayoutEditor = Notification.Name("PickPalette.openLayoutEditor")
}

/// Keyboard key cap visual.
struct KeyCapView: View {
    let key: String

    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(key)
            .font(.system(size: 12, weight: .medium))
            .frame(minWidth: 24, minHeight: 24)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(SettingsTheme.controlBackground(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
    }
}
