import SwiftUI

/// Main popover content with macOS Tahoe glass aesthetic.
struct PopoverContentView: View {
    @Bindable var appState: AppState
    var onOpenSettings: () -> Void = {}
    var onEyedropper: () -> Void = {}

    @State private var hexFieldText: String = ""
    @State private var isEditingHex: Bool = false
    @FocusState private var hexFieldFocused: Bool
    @State private var showOnboarding: Bool = false

    private var popoverWidth: CGFloat {
        appState.popoverLayout == .horizontal ? 420 : 280
    }

    // Horizontal layout dimensions
    private var horizontalSpectrumSize: CGFloat { 106 }

    // Whether any middle content (spectrum, sliders, recent) is visible
    private var hasMiddleContent: Bool {
        !appState.compactMode && (appState.showSpectrumPicker || appState.showSliders || appState.showRecentColors)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerRow
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if hasMiddleContent {
                // Top divider — only when middle content is visible
                Divider()
                    .opacity(0.5)
                    .padding(.horizontal, 10)

                // Layout-dependent middle section
                if appState.popoverLayout == .horizontal {
                    horizontalContent
                } else {
                    verticalContent
                }

                // Bottom divider — only after middle content
                Divider()
                    .opacity(0.5)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
            }

            // Bottom toolbar
            bottomToolbar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(width: popoverWidth)
        .animation(.spring(duration: 0.3), value: appState.compactMode)
        .animation(.spring(duration: 0.3), value: appState.popoverLayout)
        .onChange(of: appState.currentColor) { _, _ in
            if !hexFieldFocused {
                hexFieldText = appState.currentColor.hexString
            }
        }
        .onAppear {
            hexFieldText = appState.currentColor.hexString
            showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        }
        .overlay {
            if appState.showCopiedFeedback {
                copiedBanner
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.85)),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
            }
        }
        .overlay {
            if showOnboarding {
                OnboardingOverlay(isPresented: $showOnboarding)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(duration: 0.3), value: appState.showCopiedFeedback)
        .animation(.spring(duration: 0.3), value: showOnboarding)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 12) {
            // Color swatch with glass ring
            if appState.showColorSwatch {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 52, height: 52)

                    Circle()
                        .fill(appState.currentColor.color)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .shadow(color: appState.currentColor.color.opacity(0.3), radius: 6, y: 2)
            }

            VStack(alignment: .leading, spacing: 5) {
                // Color space picker — custom glass segmented control
                if appState.showColorSpaceTabs {
                    GlassSegmentedControl(
                        selection: $appState.activeColorSpace,
                        options: [
                            (ColorSpaceGroup.hsl, "HSL"),
                            (ColorSpaceGroup.hsb, "HSB"),
                            (ColorSpaceGroup.rgb, "RGB")
                        ]
                    )
                }

                // Hex field
                if appState.showHexField {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)

                        TextField("FFFFFF", text: $hexFieldText, onEditingChanged: { editing in
                            isEditingHex = editing
                        }, onCommit: {
                            if let color = ColorModel.fromHex(hexFieldText) {
                                appState.currentColor = color
                            } else {
                                hexFieldText = appState.currentColor.hexString
                            }
                            isEditingHex = false
                        })
                        .focused($hexFieldFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Vertical Content (default)

    @ViewBuilder
    private var verticalContent: some View {
        // Color picker area
        if appState.showSpectrumPicker {
            SpectrumPickerView(
                appState: appState,
                width: popoverWidth - 28,
                height: 170
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)
        }

        // Channel sliders
        if appState.showSliders {
            ColorSlidersView(appState: appState)
                .padding(.horizontal, 14)
                .padding(.top, 10)
        }

        // Recent colors
        if appState.showRecentColors {
            RecentColorsView(appState: appState)
                .padding(.horizontal, 14)
                .padding(.top, 8)
        }
    }

    // MARK: - Horizontal Content

    @ViewBuilder
    private var horizontalContent: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left: square spectrum picker
            if appState.showSpectrumPicker {
                SpectrumPickerView(
                    appState: appState,
                    width: horizontalSpectrumSize,
                    height: horizontalSpectrumSize
                )
            }

            // Right: stacked sliders
            if appState.showSliders {
                ColorSlidersView(appState: appState)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)

        // Recent colors full-width below
        if appState.showRecentColors {
            RecentColorsView(appState: appState)
                .padding(.horizontal, 14)
                .padding(.top, 8)
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 6) {
            // Eyedropper button
            ToolbarButton(icon: "eyedropper", tooltip: "Pick color from screen") {
                onEyedropper()
            }

            Spacer()

            // Copy button 1
            CopyFormatButton(format: appState.copyButton1Format) {
                appState.copyColor(format: appState.copyButton1Format)
                appState.addToRecent(appState.currentColor)
            }

            // Copy button 2
            CopyFormatButton(format: appState.copyButton2Format) {
                appState.copyColor(format: appState.copyButton2Format)
                appState.addToRecent(appState.currentColor)
            }

            Spacer()

            // Settings button — gear icon
            ToolbarButton(icon: "gearshape", tooltip: "Settings") {
                onOpenSettings()
            }
        }
    }

    // MARK: - Copied Banner

    private var copiedBanner: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
                    .shadow(color: .green.opacity(0.4), radius: 6)
                Text("Copied \(appState.copiedFormatName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    Capsule()
                        .fill(.black.opacity(0.55))
                    Capsule()
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                }
            )
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                        .opacity(isHovering ? 1 : 0)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help(tooltip)
    }
}

// MARK: - Copy Format Button

struct CopyFormatButton: View {
    let format: ColorFormat
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                Text(format.name)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isHovering ? .primary : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                    .opacity(isHovering ? 1 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help("Copy as \(format.name)")
    }
}

// MARK: - Glass Segmented Control

struct GlassSegmentedControl<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]

    @Namespace private var segmentNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = selection == option.0
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        selection = option.0
                    }
                } label: {
                    Text(option.1)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.accentColor.gradient)
                                    .shadow(color: Color.accentColor.opacity(0.35), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "segment", in: segmentNamespace)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2.5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}
