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
    var width: CGFloat = 28
    var height: CGFloat = 28
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    private var dim: CGFloat { min(width, height) }
    private var iconSize: CGFloat { max(8, dim * 0.46) }
    private var cornerRadius: CGFloat { max(3, dim * 0.21) }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(
                    isHovering
                        ? Color.primary
                        : PopoverTheme.secondaryTextColor(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        )
                )
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
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
    var width: CGFloat = 80
    var height: CGFloat = 28
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    private var scale: CGFloat { min(width / 80.0, height / 28.0) }
    private var iconFont: CGFloat { max(7, 10 * scale) }
    private var textFont: CGFloat { max(8, 11 * scale) }
    private var hPadding: CGFloat { max(4, 8 * scale) }
    private var vPadding: CGFloat { max(3, 6 * scale) }
    private var spacing: CGFloat { max(2, 4 * scale) }
    private var cornerRadius: CGFloat { max(3, 6 * scale) }
    private var showLabel: Bool { width >= 40 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: spacing) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: iconFont, weight: .medium))
                if showLabel {
                    Text(format.name)
                        .font(.system(size: textFont, weight: .medium))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(
                isHovering
                    ? Color.primary
                    : PopoverTheme.secondaryTextColor(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    )
            )
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        PopoverTheme.controlBackground(
                            useGlassStyle: useGlassStyle,
                            colorScheme: colorScheme
                        )
                    )
                    .opacity(isHovering ? 1 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
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
    var height: CGFloat = 34
    var orientation: Axis = .horizontal

    @Namespace private var segmentNamespace
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    private var scale: CGFloat { height / 34.0 }
    private var textSize: CGFloat { max(7, 10 * scale) }
    private var segmentVPadding: CGFloat { max(1, 3 * scale) }
    private var containerPadding: CGFloat { max(1, 2 * scale) }
    private var segmentSpacing: CGFloat { max(1, 2 * scale) }
    private var segmentRadius: CGFloat { max(2, 4 * scale) }
    private var containerRadius: CGFloat { max(3, 6 * scale) }
    private var shadowRadius: CGFloat { max(1, 4 * scale) }

    var body: some View {
        let layout = orientation == .horizontal
            ? AnyLayout(HStackLayout(spacing: segmentSpacing))
            : AnyLayout(VStackLayout(spacing: segmentSpacing))

        layout {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = selection == option.0
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        selection = option.0
                    }
                } label: {
                    Text(option.1)
                        .font(.system(size: textSize, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity, maxHeight: orientation == .vertical ? .infinity : nil)
                        .padding(.vertical, segmentVPadding)
                        .padding(.horizontal, orientation == .vertical ? segmentVPadding : 0)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: segmentRadius)
                                    .fill(Color.accentColor.gradient)
                                    .shadow(color: Color.accentColor.opacity(0.35), radius: shadowRadius, y: max(0.5, 1 * scale))
                                    .matchedGeometryEffect(id: "segment", in: segmentNamespace)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: segmentRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(containerPadding)
        .background(
            RoundedRectangle(cornerRadius: containerRadius)
                .fill(
                    PopoverTheme.subtleFill(
                        useGlassStyle: useGlassStyle,
                        colorScheme: colorScheme
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: containerRadius)
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
