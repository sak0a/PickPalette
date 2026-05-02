import SwiftUI

// MARK: - Key Event Handler (NSViewRepresentable)

/// An invisible NSView that becomes first responder to capture keyboard events.
/// Used for arrow-key nudging and Delete to remove the selected widget.
struct KeyEventView: NSViewRepresentable {
    var onArrow: (_ dx: CGFloat, _ dy: CGFloat) -> Void
    var onDelete: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onArrow = onArrow
        view.onDelete = onDelete
        // Schedule becoming first responder after the view is in the window hierarchy
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onArrow = onArrow
        nsView.onDelete = onDelete
    }

    class KeyCaptureNSView: NSView {
        var onArrow: ((_ dx: CGFloat, _ dy: CGFloat) -> Void)?
        var onDelete: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Grab first responder when entering the window
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1

            switch event.keyCode {
            case 123: onArrow?(-step, 0)  // left arrow
            case 124: onArrow?(step, 0)   // right arrow
            case 125: onArrow?(0, step)   // down arrow
            case 126: onArrow?(0, -step)  // up arrow
            case 42:                      // backslash (\)
                onDelete?()
            case 51, 117:                 // backspace, forward delete
                onDelete?()
            default:
                super.keyDown(with: event)
            }
        }
    }
}

// MARK: - Scroll Wheel Zoom (NSViewRepresentable)

/// An invisible NSView overlay that intercepts mouse scroll-wheel events for zoom.
/// Trackpad two-finger scrolls pass through to the ScrollView for panning.
struct ScrollWheelZoomView: NSViewRepresentable {
    var onZoom: (CGFloat) -> Void

    func makeNSView(context: Context) -> ZoomCaptureNSView {
        let view = ZoomCaptureNSView()
        view.onZoom = onZoom
        return view
    }

    func updateNSView(_ nsView: ZoomCaptureNSView, context: Context) {
        nsView.onZoom = onZoom
    }

    class ZoomCaptureNSView: NSView {
        var onZoom: ((CGFloat) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            if !event.hasPreciseScrollingDeltas {
                // Mouse scroll wheel → zoom (no modifier needed)
                let delta = event.scrollingDeltaY * 0.05
                onZoom?(delta)
            } else {
                // Trackpad two-finger scroll → pass through for panning
                super.scrollWheel(with: event)
            }
        }
    }
}

// MARK: - CGFloat Zoom Helpers

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

/// Root view for the layout editor window.
/// Shows a scaled canvas with dot-grid background, editable widgets, snap guides,
/// toolbar with add/zoom/preset controls, and a right-side inspector panel.
struct LayoutEditorView: View {
    @Bindable var appState: AppState
    var onDone: () -> Void

    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 5.0

    @State private var canvasScale: CGFloat = 2.0
    @State private var selectedWidgetID: UUID? = nil
    @State private var activeGuides: [SnapGuide] = []
    @State private var saveTask: Task<Void, Never>? = nil
    @State private var dotGridSpacing: CGFloat = 20
    @State private var canvasViewportSize: CGSize = .zero
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    private var layout: PopoverLayoutConfig {
        appState.layoutConfig
    }

    var body: some View {
        ZStack {
            // Invisible key event handler (captures arrow keys + delete)
            KeyEventView(
                onArrow: { dx, dy in
                    nudgeSelectedWidget(dx: dx, dy: dy)
                },
                onDelete: {
                    deleteSelectedWidget()
                }
            )
            .frame(width: 0, height: 0)

            VStack(spacing: 0) {
                // Toolbar
                editorToolbar

                Divider().opacity(0.3)

                // Main content: canvas + inspector
                HStack(spacing: 0) {
                    // Canvas area
                    GeometryReader { geo in
                        ScrollView([.horizontal, .vertical]) {
                            canvasContent
                                .padding(40)
                        }
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .onTapGesture {
                            selectedWidgetID = nil
                        }
                        // Pinch-to-zoom on trackpad
                        .simultaneousGesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    let newScale = (canvasScale * value.magnification)
                                        .clamped(to: minZoom...maxZoom)
                                    canvasScale = newScale
                                }
                        )
                        // Mouse scroll wheel → zoom, trackpad scroll → pan
                        .overlay {
                            ScrollWheelZoomView { delta in
                                let newScale = (canvasScale + delta).clamped(to: minZoom...maxZoom)
                                canvasScale = newScale
                            }
                            .allowsHitTesting(true)
                        }
                        .onAppear { canvasViewportSize = geo.size }
                        .onChange(of: geo.size) { _, newSize in canvasViewportSize = newSize }
                    }

                    Divider().opacity(0.3)

                    // Inspector sidebar
                    EditorInspectorView(
                        appState: appState,
                        selectedWidgetID: $selectedWidgetID,
                        dotGridSpacing: $dotGridSpacing
                    )
                }
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .environment(\.useGlassStyle, appState.effectiveGlassStyle)
        .onAppear {
            dotGridSpacing = appState.layoutConfig.dotGridSpacing
        }
        .onChange(of: appState.layoutConfig.containerWidth) { _, _ in
            debouncedSave()
        }
        .onChange(of: appState.layoutConfig.containerHeight) { _, _ in
            debouncedSave()
        }
        .onDisappear {
            saveTask?.cancel()
            appState.save()
        }
    }

    // MARK: - Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            Text("Edit Layout")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            AddWidgetMenu(appState: appState)

            Spacer()

            // Zoom controls
            HStack(spacing: 6) {
                // Fit button
                Button {
                    zoomToFit()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Zoom to Fit")

                // Zoom slider
                Slider(value: $canvasScale, in: minZoom...maxZoom)
                    .frame(width: 80)
                    .controlSize(.small)

                // Current zoom percentage
                Text("\(Int(canvasScale * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }

            // Preset menu
            presetMenu

            Button {
                saveTask?.cancel()
                appState.save()
                onDone()
            } label: {
                Text("Done")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.gradient)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            useGlassStyle
                ? AnyShapeStyle(.ultraThinMaterial)
                : AnyShapeStyle(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.94))
        )
    }

    // MARK: - Preset Menu

    private var presetMenu: some View {
        Menu {
            ForEach(PopoverLayoutConfig.presets, id: \.name) { preset in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        appState.layoutConfig = preset
                        appState.save()
                    }
                } label: {
                    Label(preset.name, systemImage: presetIcon(for: preset.name))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 10, weight: .medium))
                Text("Presets")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.primary.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Canvas Content

    private var canvasContent: some View {
        ZStack(alignment: .topLeading) {
            // Canvas background with dot grid
            dotGridBackground
                .frame(width: layout.containerWidth, height: layout.containerHeight)

            // Rendered widgets (non-interactive preview)
            ForEach(layout.widgets) { widget in
                WidgetFactory.view(
                    for: widget,
                    appState: appState,
                    availableWidth: widget.width ?? 252,
                    onOpenSettings: {},
                    onEyedropper: {}
                )
                .frame(
                    width: widget.width ?? 252,
                    height: widget.height ?? WidgetSizeConstraints.constraints(for: widget.widgetType).defaultHeight
                )
                .clipped()
                .opacity(widget.isEnabled ? 1.0 : 0.35)
                .allowsHitTesting(false)
                .offset(x: widget.x ?? 0, y: widget.y ?? 0)
            }

            // Edit overlays
            ForEach(layout.widgets) { widget in
                CanvasEditOverlay(
                    config: widget,
                    appState: appState,
                    canvasScale: canvasScale,
                    isSelected: selectedWidgetID == widget.id,
                    onSelect: {
                        selectedWidgetID = widget.id
                    },
                    onGuides: { guides in
                        activeGuides = guides
                    }
                )
            }

            // Snap guide lines
            ForEach(activeGuides) { guide in
                snapGuideLine(guide)
            }
        }
        .frame(width: layout.containerWidth, height: layout.containerHeight)
        .drawingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        .scaleEffect(canvasScale, anchor: .topLeading)
        .frame(
            width: layout.containerWidth * canvasScale,
            height: layout.containerHeight * canvasScale,
            alignment: .topLeading
        )
    }

    // MARK: - Dot Grid Background

    private var dotGridBackground: some View {
        Canvas { context, size in
            let spacing = dotGridSpacing
            guard spacing > 0 else { return }
            let dotRadius: CGFloat = 0.75
            let color = Color.primary.opacity(0.1)

            var y: CGFloat = spacing
            while y < size.height {
                var x: CGFloat = spacing
                while x < size.width {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)),
                        with: .color(color)
                    )
                    x += spacing
                }
                y += spacing
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Snap Guide Line

    @ViewBuilder
    private func snapGuideLine(_ guide: SnapGuide) -> some View {
        switch guide.orientation {
        case .horizontal:
            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: layout.containerWidth, height: 1)
                .offset(y: guide.position)
        case .vertical:
            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 1, height: layout.containerHeight)
                .offset(x: guide.position)
        }
    }

    // MARK: - Zoom Actions

    private func zoomToFit() {
        guard canvasViewportSize.width > 0, canvasViewportSize.height > 0 else { return }
        let padding: CGFloat = 80  // leave some margin
        let scaleX = (canvasViewportSize.width - padding) / layout.containerWidth
        let scaleY = (canvasViewportSize.height - padding) / layout.containerHeight
        let fitScale = min(scaleX, scaleY).clamped(to: minZoom...maxZoom)
        withAnimation(.spring(duration: 0.3)) {
            canvasScale = fitScale
        }
    }

    // MARK: - Keyboard Actions

    private func nudgeSelectedWidget(dx: CGFloat, dy: CGFloat) {
        guard let widgetID = selectedWidgetID,
              let index = appState.layoutConfig.widgets.firstIndex(where: { $0.id == widgetID }) else { return }
        appState.layoutConfig.widgets[index].x = (appState.layoutConfig.widgets[index].x ?? 0) + dx
        appState.layoutConfig.widgets[index].y = (appState.layoutConfig.widgets[index].y ?? 0) + dy
        debouncedSave()
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            appState.save()
        }
    }

    private func deleteSelectedWidget() {
        guard let widgetID = selectedWidgetID else { return }
        appState.layoutConfig.widgets.removeAll { $0.id == widgetID }
        selectedWidgetID = nil
        appState.save()
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
