import SwiftUI

/// Resize handle positions around a widget.
enum ResizeEdge: CaseIterable {
    case topLeft, top, topRight, right
    case bottomRight, bottom, bottomLeft, left
}

/// Per-widget editing overlay — click to select, drag to move, resize handles on edges/corners.
struct CanvasEditOverlay: View {
    let config: WidgetConfig
    @Bindable var appState: AppState
    let canvasScale: CGFloat
    let isSelected: Bool
    var onSelect: () -> Void
    var onGuides: (_ guides: [SnapGuide]) -> Void

    @State private var isDragging = false
    @State private var dragStartX: CGFloat = 0
    @State private var dragStartY: CGFloat = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isHovering = false
    @Environment(\.useGlassStyle) private var useGlassStyle
    @Environment(\.colorScheme) private var colorScheme

    // Resize state
    @State private var isResizing = false
    @State private var resizeStartRect: CGRect = .zero
    @State private var liveResizeRect: CGRect? = nil

    private var constraints: WidgetSizeConstraints {
        WidgetSizeConstraints.constraints(for: config.widgetType)
    }

    private var widgetX: CGFloat {
        if let r = liveResizeRect { return r.origin.x }
        return (config.x ?? 0) + dragOffset.width
    }
    private var widgetY: CGFloat {
        if let r = liveResizeRect { return r.origin.y }
        return (config.y ?? 0) + dragOffset.height
    }
    private var widgetW: CGFloat {
        if let r = liveResizeRect { return r.size.width }
        return config.width ?? constraints.defaultWidth
    }
    private var widgetH: CGFloat {
        if let r = liveResizeRect { return r.size.height }
        return config.height ?? constraints.defaultHeight
    }
    private var controlSurfaceStyle: AnyShapeStyle {
        useGlassStyle
            ? AnyShapeStyle(.ultraThinMaterial)
            : AnyShapeStyle(colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.93))
    }

    /// Dynamic display name — copy buttons show their format name.
    private var displayName: String {
        if config.widgetType == .copyButton {
            let name = appState.formats.first(where: { $0.id == config.formatID })?.name ?? "HEX"
            return "Copy \(name)"
        }
        return config.widgetType.displayName
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Selection / hover border
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(
                    isSelected ? Color.accentColor : (isHovering ? Color.primary.opacity(0.2) : Color.primary.opacity(0.08)),
                    style: StrokeStyle(lineWidth: 0.5, dash: isSelected ? [] : [4, 3])
                )
                .frame(width: widgetW, height: widgetH)

            // Widget name label (visible on hover or selection)
            if isHovering || isSelected {
                widgetLabel
            }

            // Control buttons (visible when selected)
            if isSelected {
                controlButtons
            }

            // Size badge during resize
            if isResizing {
                sizeBadge
            }
        }
        .frame(width: widgetW, height: widgetH)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .gesture(moveGesture)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .overlay {
            if isSelected {
                resizeHandles
            }
        }
        .offset(x: widgetX, y: widgetY)
    }

    // MARK: - Widget Label

    private var widgetLabel: some View {
        VStack {
            HStack {
                HStack(spacing: 2) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 4, weight: .bold))
                    Text(displayName)
                        .font(.system(size: 5, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(controlSurfaceStyle)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                )
                .offset(x: 2, y: 2)

                Spacer()
            }
            Spacer()
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        VStack {
            HStack {
                Spacer()

                HStack(spacing: 1) {
                    // Format picker (copy buttons only)
                    if config.widgetType == .copyButton {
                        formatPicker
                    }

                    // Eye toggle
                    editButton(
                        icon: config.isEnabled ? "eye" : "eye.slash",
                        color: config.isEnabled ? .primary : .orange
                    ) {
                        toggleEnabled()
                    }

                    // Delete
                    editButton(icon: "xmark.circle", color: .red) {
                        deleteWidget()
                    }
                }
                .offset(x: -2, y: 2)
            }
            Spacer()
        }
    }

    // MARK: - Size Badge

    private var sizeBadge: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("\(Int(widgetW))×\(Int(widgetH))")
                    .font(.system(size: 5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(controlSurfaceStyle)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
                    )
                Spacer()
            }
            .offset(y: -3)
        }
    }

    // MARK: - Move Gesture

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartX = config.x ?? 0
                    dragStartY = config.y ?? 0
                    onSelect()
                }

                let dx = value.translation.width / canvasScale
                let dy = value.translation.height / canvasScale

                let baseW = config.width ?? constraints.defaultWidth
                let baseH = config.height ?? constraints.defaultHeight
                let proposedRect = CGRect(x: dragStartX + dx, y: dragStartY + dy, width: baseW, height: baseH)
                let containerSize = CGSize(
                    width: appState.layoutConfig.containerWidth,
                    height: appState.layoutConfig.containerHeight
                )
                let otherWidgets = appState.layoutConfig.widgets.filter { $0.id != config.id }
                let snapResult = SnapGuideEngine.computeSnap(
                    for: proposedRect,
                    in: containerSize,
                    others: otherWidgets,
                    threshold: 5,
                    gridSpacing: appState.layoutConfig.dotGridSpacing
                )

                // Update local offset only — no appState mutation during drag
                dragOffset = CGSize(
                    width: snapResult.snappedRect.origin.x - (config.x ?? 0),
                    height: snapResult.snappedRect.origin.y - (config.y ?? 0)
                )
                onGuides(snapResult.activeGuides)
            }
            .onEnded { _ in
                // Commit final position to appState once
                let finalX = (config.x ?? 0) + dragOffset.width
                let finalY = (config.y ?? 0) + dragOffset.height
                updatePosition(x: finalX, y: finalY)
                dragOffset = .zero
                isDragging = false
                onGuides([])
                appState.save()
            }
    }

    // MARK: - Resize Handles

    private var resizeHandles: some View {
        ZStack(alignment: .topLeading) {
            ForEach(ResizeEdge.allCases, id: \.self) { edge in
                resizeHandle(for: edge)
            }
        }
        .frame(width: widgetW, height: widgetH, alignment: .topLeading)
    }

    @ViewBuilder
    private func resizeHandle(for edge: ResizeEdge) -> some View {
        let handleSize: CGFloat = 4

        Circle()
            .fill(Color.accentColor)
            .frame(width: handleSize, height: handleSize)
            .shadow(color: Color.accentColor.opacity(0.3), radius: 1)
            .offset(handleOffset(for: edge, size: CGSize(width: widgetW, height: widgetH)))
            .gesture(resizeGesture(for: edge))
            .onHover { hovering in
                if hovering {
                    resizeCursor(for: edge).push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    private func handleOffset(for edge: ResizeEdge, size: CGSize) -> CGSize {
        let w = size.width
        let h = size.height
        let half: CGFloat = 2  // handleSize / 2 — centers the circle on the edge
        switch edge {
        case .topLeft:     return CGSize(width: -half,        height: -half)
        case .top:         return CGSize(width: w / 2 - half, height: -half)
        case .topRight:    return CGSize(width: w - half,     height: -half)
        case .right:       return CGSize(width: w - half,     height: h / 2 - half)
        case .bottomRight: return CGSize(width: w - half,     height: h - half)
        case .bottom:      return CGSize(width: w / 2 - half, height: h - half)
        case .bottomLeft:  return CGSize(width: -half,        height: h - half)
        case .left:        return CGSize(width: -half,        height: h / 2 - half)
        }
    }

    private func resizeCursor(for edge: ResizeEdge) -> NSCursor {
        switch edge {
        case .top, .bottom: return .resizeUpDown
        case .left, .right: return .resizeLeftRight
        case .topLeft, .bottomRight: return .resizeUpDown // ideally diagonal, macOS doesn't have built-in
        case .topRight, .bottomLeft: return .resizeUpDown
        }
    }

    private func resizeGesture(for edge: ResizeEdge) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isResizing {
                    isResizing = true
                    let baseW = config.width ?? constraints.defaultWidth
                    let baseH = config.height ?? constraints.defaultHeight
                    resizeStartRect = CGRect(x: config.x ?? 0, y: config.y ?? 0, width: baseW, height: baseH)
                }

                let dx = value.translation.width / canvasScale
                let dy = value.translation.height / canvasScale

                var newRect = resizeStartRect

                // Adjust rect based on which edge is being dragged
                switch edge {
                case .topLeft:
                    newRect.origin.x += dx
                    newRect.origin.y += dy
                    newRect.size.width -= dx
                    newRect.size.height -= dy
                case .top:
                    newRect.origin.y += dy
                    newRect.size.height -= dy
                case .topRight:
                    newRect.size.width += dx
                    newRect.origin.y += dy
                    newRect.size.height -= dy
                case .right:
                    newRect.size.width += dx
                case .bottomRight:
                    newRect.size.width += dx
                    newRect.size.height += dy
                case .bottom:
                    newRect.size.height += dy
                case .bottomLeft:
                    newRect.origin.x += dx
                    newRect.size.width -= dx
                    newRect.size.height += dy
                case .left:
                    newRect.origin.x += dx
                    newRect.size.width -= dx
                }

                // Enforce min sizes
                let minW = constraints.minWidth
                let minH = constraints.minHeight

                if newRect.size.width < minW {
                    if edge == .left || edge == .topLeft || edge == .bottomLeft {
                        newRect.origin.x = resizeStartRect.maxX - minW
                    }
                    newRect.size.width = minW
                }
                if newRect.size.height < minH {
                    if edge == .top || edge == .topLeft || edge == .topRight {
                        newRect.origin.y = resizeStartRect.maxY - minH
                    }
                    newRect.size.height = minH
                }

                // Enforce max height if present
                if let maxH = constraints.maxHeight, newRect.size.height > maxH {
                    newRect.size.height = maxH
                }

                // Snap during resize
                let containerSize = CGSize(
                    width: appState.layoutConfig.containerWidth,
                    height: appState.layoutConfig.containerHeight
                )
                let otherWidgets = appState.layoutConfig.widgets.filter { $0.id != config.id }
                let snapResult = SnapGuideEngine.computeSnap(
                    for: newRect,
                    in: containerSize,
                    others: otherWidgets,
                    threshold: 5,
                    gridSpacing: appState.layoutConfig.dotGridSpacing
                )

                // Update local state only — no appState mutation during resize
                liveResizeRect = snapResult.snappedRect
                onGuides(snapResult.activeGuides)
            }
            .onEnded { _ in
                // Commit final rect to appState once
                if let finalRect = liveResizeRect {
                    updateRect(finalRect)
                }
                liveResizeRect = nil
                isResizing = false
                onGuides([])
                appState.save()
            }
    }

    // MARK: - Format Picker

    private var formatPicker: some View {
        Menu {
            ForEach(appState.formats) { format in
                Button {
                    updateFormatID(format.id)
                } label: {
                    HStack {
                        Text(format.name)
                        if config.formatID == format.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "textformat")
                .font(.system(size: 5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 10, height: 10)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(controlSurfaceStyle)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Edit Button Helper

    private func editButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 5, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 10, height: 10)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(controlSurfaceStyle)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggleEnabled() {
        guard let index = appState.layoutConfig.widgets.firstIndex(where: { $0.id == config.id }) else { return }
        appState.layoutConfig.widgets[index].isEnabled.toggle()
        appState.save()
    }

    private func deleteWidget() {
        appState.layoutConfig.widgets.removeAll { $0.id == config.id }
        appState.save()
    }

    private func updatePosition(x: CGFloat, y: CGFloat) {
        guard let index = appState.layoutConfig.widgets.firstIndex(where: { $0.id == config.id }) else { return }
        appState.layoutConfig.widgets[index].x = x
        appState.layoutConfig.widgets[index].y = y
    }

    private func updateRect(_ rect: CGRect) {
        guard let index = appState.layoutConfig.widgets.firstIndex(where: { $0.id == config.id }) else { return }
        appState.layoutConfig.widgets[index].x = rect.origin.x
        appState.layoutConfig.widgets[index].y = rect.origin.y
        appState.layoutConfig.widgets[index].width = rect.size.width
        appState.layoutConfig.widgets[index].height = rect.size.height
        // Also update customHeight for widgets that use it
        appState.layoutConfig.widgets[index].customHeight = rect.size.height
    }

    private func updateFormatID(_ formatID: UUID) {
        guard let index = appState.layoutConfig.widgets.firstIndex(where: { $0.id == config.id }) else { return }
        appState.layoutConfig.widgets[index].formatID = formatID
        appState.save()
    }
}
