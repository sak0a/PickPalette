import SwiftUI
import ServiceManagement
import ScreenCaptureKit
import Carbon

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable, Hashable {
    case general
    case appearance
    case formats
    case palettes

    var label: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .formats: return "Formats"
        case .palettes: return "Palettes"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .formats: return "textformat"
        case .palettes: return "paintpalette"
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            settingsSidebar
                .frame(width: 160)

            // Divider
            Rectangle()
                .fill(.primary.opacity(0.06))
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(duration: 0.3, bounce: 0.1), value: selectedTab)
        }
        .frame(width: 600, height: 480)
    }

    // MARK: - Sidebar

    @Namespace private var sidebarNamespace

    private var settingsSidebar: some View {
        VStack(spacing: 4) {
            // Title area
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.quaternary)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial.opacity(0.5))
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

                        GlassPicker(
                            label: "Appearance",
                            selection: $appState.appearance,
                            options: AppearanceMode.allCases.map { ($0, $0.displayName) }
                        )
                    }
                }

                GlassSection(title: "Behavior") {
                    VStack(spacing: 12) {
                        GlassToggle(
                            label: "Compact Mode",
                            isOn: $appState.compactMode
                        )

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

                GlassSection(title: "Keyboard Shortcut") {
                    ShortcutRecorderRow(appState: appState)
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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isGranted ? .green : .orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isGranted ? .green : .orange)
                }
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
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
                                .fill(.ultraThinMaterial)
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
                    .font(.system(size: 10, weight: .medium))
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
                GlassSection(title: "Layout") {
                    GlassToggle(
                        label: "Horizontal Layout",
                        isOn: Binding(
                            get: { appState.popoverLayout == .horizontal },
                            set: { appState.popoverLayout = $0 ? .horizontal : .vertical }
                        )
                    )
                }

                GlassSection(title: "Quick Copy Buttons") {
                    VStack(spacing: 12) {
                        GlassPicker(
                            label: "Button 1",
                            selection: $appState.copyButton1FormatID,
                            options: appState.formats.map { ($0.id, $0.name) }
                        )

                        GlassPicker(
                            label: "Button 2",
                            selection: $appState.copyButton2FormatID,
                            options: appState.formats.map { ($0.id, $0.name) }
                        )
                    }
                }

                GlassSection(title: "Popover Elements") {
                    VStack(spacing: 12) {
                        GlassToggle(
                            label: "Color Preview",
                            isOn: $appState.showColorSwatch
                        )

                        GlassToggle(
                            label: "Color Space Tabs",
                            isOn: $appState.showColorSpaceTabs
                        )

                        GlassToggle(
                            label: "Hex Input Field",
                            isOn: $appState.showHexField
                        )

                        GlassToggle(
                            label: "Spectrum Picker",
                            isOn: $appState.showSpectrumPicker
                        )

                        GlassToggle(
                            label: "Channel Sliders",
                            isOn: $appState.showSliders
                        )

                        GlassToggle(
                            label: "Recent Colors",
                            isOn: $appState.showRecentColors
                        )
                    }
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
            .background(.ultraThinMaterial.opacity(0.3))

            Rectangle()
                .fill(.primary.opacity(0.06))
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
            .background(.ultraThinMaterial.opacity(0.3))

            Rectangle()
                .fill(.primary.opacity(0.06))
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

// MARK: - Reusable Glass Components

/// Glass section card with a title and content.
struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial.opacity(0.6))
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
                        .fill(.ultraThinMaterial)
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

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium, design: isMonospaced ? .monospaced : .default))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(.ultraThinMaterial)
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
                    .fill(.ultraThinMaterial)
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

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.ultraThinMaterial)
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

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.ultraThinMaterial)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 20)

                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : (isHovering ? .primary : .secondary))

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
                        .foregroundStyle(.tertiary)
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
                    .fill(.ultraThinMaterial)
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

/// Notification name for hotkey trigger.
extension Notification.Name {
    static let pickColorHotkey = Notification.Name("PickPalette.pickColorHotkey")
}

/// Keyboard key cap visual.
struct KeyCapView: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 12, weight: .medium))
            .frame(minWidth: 24, minHeight: 24)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
    }
}
