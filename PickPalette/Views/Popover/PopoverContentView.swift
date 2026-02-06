import SwiftUI

/// Main popover content — thin shell wrapping the widget canvas.
struct PopoverContentView: View {
    @Bindable var appState: AppState
    var onOpenSettings: () -> Void = {}
    var onEyedropper: () -> Void = {}
    var onEditLayout: () -> Void = {}

    @State private var showOnboarding: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            WidgetCanvasView(
                appState: appState,
                onOpenSettings: onOpenSettings,
                onEyedropper: onEyedropper
            )
        }
        .frame(
            width: appState.layoutConfig.containerWidth,
            height: appState.layoutConfig.containerHeight
        )
        .background(
            PopoverTheme.rootBackground(
                useGlassStyle: appState.effectiveGlassStyle,
                colorScheme: colorScheme
            )
        )
        .foregroundStyle(
            PopoverTheme.primaryTextColor(
                useGlassStyle: appState.effectiveGlassStyle,
                colorScheme: colorScheme
            )
        )
        .contextMenu {
            Button {
                onEditLayout()
            } label: {
                Label("Edit Layout", systemImage: "rectangle.3.group")
            }
        }
        .onAppear {
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
        .animation(.spring(duration: 0.3), value: appState.layoutConfig)
        .preferredColorScheme(appState.appearance.colorSchemeOverride)
        .environment(\.useGlassStyle, appState.effectiveGlassStyle)
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
                        .fill(
                            PopoverTheme.bannerBackground(
                                useGlassStyle: appState.effectiveGlassStyle,
                                colorScheme: colorScheme
                            )
                        )
                    Capsule()
                        .strokeBorder(
                            PopoverTheme.subtleStroke(
                                useGlassStyle: appState.effectiveGlassStyle,
                                colorScheme: colorScheme
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    isHovering
                        ? Color.primary
                        : PopoverTheme.secondaryTextColor(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        )
                )
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            PopoverTheme.controlBackground(
                                useGlassStyle: useGlassStyle,
                                colorScheme: colorScheme
                            )
                        )
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
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                Text(format.name)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(
                isHovering
                    ? Color.primary
                    : PopoverTheme.secondaryTextColor(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    )
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        PopoverTheme.controlBackground(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        )
                    )
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
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

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
                        .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor.gradient)
                                    .shadow(color: Color.accentColor.opacity(0.35), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "segment", in: segmentNamespace)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    PopoverTheme.subtleFill(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    PopoverTheme.subtleStroke(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    ),
                    lineWidth: 0.5
                )
        )
    }
}
