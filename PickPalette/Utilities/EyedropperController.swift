import AppKit
import ScreenCaptureKit
import CoreImage

/// Custom eyedropper using ScreenCaptureKit for pixel sampling.
/// Uses pure AppKit/CoreGraphics for the loupe to avoid SwiftUI layout issues.
final class EyedropperController {
    private var overlayWindow: OverlayWindow?
    private var loupePanel: NSPanel?
    private var loupeView: LoupeNSView?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var completion: ((NSColor?) -> Void)?
    private var updateTimer: Timer?
    private var isFinishing = false

    // ScreenCaptureKit state
    private var stream: SCStream?
    private var streamOutput: ScreenCaptureOutput?

    private let loupeSize: CGFloat = 140
    private let previewHeight: CGFloat = 40
    private let gridSize: Int = 15

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func start(completion: @escaping (NSColor?) -> Void) {
        self.completion = completion

        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    self.fallbackToSystemPicker()
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.width)
                config.height = Int(display.height)
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = false

                let output = ScreenCaptureOutput(ciContext: Self.ciContext)
                self.streamOutput = output

                let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
                try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
                try await newStream.startCapture()
                self.stream = newStream

                self.setupOverlayAndLoupe(screenFrame: display.frame)
            } catch {
                self.fallbackToSystemPicker()
            }
        }
    }

    private func fallbackToSystemPicker() {
        NSColorSampler().show { [weak self] color in
            self?.completion?(color?.usingColorSpace(.sRGB))
            self?.completion = nil
        }
    }

    // MARK: - Setup

    private func setupOverlayAndLoupe(screenFrame: CGRect) {
        guard let screen = NSScreen.main else {
            fallbackToSystemPicker()
            return
        }

        // Overlay window that can become key (subclass overrides canBecomeKeyWindow)
        let overlay = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        overlay.level = .screenSaver
        overlay.backgroundColor = NSColor.black.withAlphaComponent(0.001)
        overlay.isOpaque = false
        overlay.ignoresMouseEvents = false
        overlay.acceptsMouseMovedEvents = true
        overlay.hasShadow = false
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let trackingView = MouseTrackingView(frame: screen.frame)
        overlay.contentView = trackingView
        overlay.orderFrontRegardless()
        overlay.makeKeyAndOrderFront(nil)
        self.overlayWindow = overlay

        // Loupe panel
        let totalHeight = loupeSize + previewHeight
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: loupeSize, height: totalHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let lView = LoupeNSView(frame: NSRect(x: 0, y: 0, width: loupeSize, height: totalHeight), gridSize: gridSize)
        panel.contentView = lView
        self.loupeView = lView

        panel.orderFrontRegardless()
        self.loupePanel = panel

        NSCursor.crosshair.push()

        // Event monitors
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }

        // Use a simple Timer on the main run loop — safe and reliable
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, !self.isFinishing else { return }
            self.updateLoupe(at: NSEvent.mouseLocation)
        }
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: NSEvent) {
        guard !isFinishing else { return }
        switch event.type {
        case .mouseMoved:
            break
        case .leftMouseDown:
            let color = getPixelColor(at: NSEvent.mouseLocation)
            finish(with: color)
        case .rightMouseDown:
            finish(with: nil)
        case .keyDown:
            if event.keyCode == 53 { finish(with: nil) }
        default:
            break
        }
    }

    // MARK: - Loupe Update

    private func updateLoupe(at screenPoint: NSPoint) {
        guard let panel = loupePanel, let lView = loupeView else { return }
        guard let frame = streamOutput?.getLatestFrame() else { return }

        // Position loupe offset from cursor
        let offset: CGFloat = 24
        var origin = NSPoint(
            x: screenPoint.x + offset,
            y: screenPoint.y - loupeSize - previewHeight - offset
        )
        if let screen = NSScreen.main {
            let f = screen.frame
            if origin.x + loupeSize > f.maxX { origin.x = screenPoint.x - loupeSize - offset }
            if origin.y < f.minY { origin.y = screenPoint.y + offset }
        }
        panel.setFrameOrigin(origin)

        let croppedImage = cropFrameAround(point: screenPoint, frame: frame, pixelCount: gridSize)
        let centerColor = getPixelColor(at: screenPoint, from: frame)

        lView.update(image: croppedImage, centerColor: centerColor)
    }

    private func cropFrameAround(point: NSPoint, frame: CGImage, pixelCount: Int) -> CGImage? {
        guard let screen = NSScreen.main else { return nil }
        let scaleX = CGFloat(frame.width) / screen.frame.width
        let scaleY = CGFloat(frame.height) / screen.frame.height
        let half = CGFloat(pixelCount) / 2.0

        let cgX = (point.x - half) * scaleX
        let cgY = (screen.frame.height - point.y - half) * scaleY
        let cropRect = CGRect(x: cgX, y: cgY, width: CGFloat(pixelCount) * scaleX, height: CGFloat(pixelCount) * scaleY)

        return frame.cropping(to: cropRect)
    }

    private func getPixelColor(at point: NSPoint, from frame: CGImage? = nil) -> NSColor? {
        let img = frame ?? streamOutput?.getLatestFrame()
        guard let img, let screen = NSScreen.main else { return nil }
        let scaleX = CGFloat(img.width) / screen.frame.width
        let scaleY = CGFloat(img.height) / screen.frame.height

        let px = Int(point.x * scaleX)
        let py = Int((screen.frame.height - point.y) * scaleY)

        guard px >= 0, py >= 0, px < img.width, py < img.height else { return nil }

        let cropRect = CGRect(x: px, y: py, width: 1, height: 1)
        guard let cropped = img.cropping(to: cropRect) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cropped)
        return bitmap.colorAt(x: 0, y: 0)
    }

    // MARK: - Finish

    private func finish(with color: NSColor?) {
        guard !isFinishing else { return }
        isFinishing = true

        // 1. Stop timer — no more updateLoupe calls
        updateTimer?.invalidate()
        updateTimer = nil

        // 2. Remove event monitors immediately
        if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
        if let lm = localMonitor { NSEvent.removeMonitor(lm) }
        globalMonitor = nil
        localMonitor = nil

        NSCursor.pop()

        // 3. Tear down windows immediately (synchronous, on main thread)
        loupeView = nil
        loupePanel?.contentView = nil
        loupePanel?.orderOut(nil)
        loupePanel = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil

        // 4. Capture the color before cleanup
        let srgb = color?.usingColorSpace(.sRGB)

        // 5. Stop the stream asynchronously but don't depend on it for completion
        let capturedStream = stream
        let capturedOutput = streamOutput
        stream = nil
        streamOutput = nil

        if let capturedStream {
            Task.detached {
                try? await capturedStream.stopCapture()
                if let capturedOutput {
                    try? capturedStream.removeStreamOutput(capturedOutput, type: .screen)
                }
            }
        }

        // 6. Call completion synchronously — the caller retains us
        completion?(srgb)
        completion = nil
    }
}

// MARK: - Overlay Window (can become key)

private class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// MARK: - ScreenCaptureKit Output Handler

final class ScreenCaptureOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var _latestFrame: CGImage?
    private let ciContext: CIContext

    init(ciContext: CIContext) {
        self.ciContext = ciContext
        super.init()
    }

    func getLatestFrame() -> CGImage? {
        lock.lock()
        let frame = _latestFrame
        lock.unlock()
        return frame
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        lock.lock()
        _latestFrame = cgImage
        lock.unlock()
    }
}

// MARK: - Mouse Tracking View

private class MouseTrackingView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }
}

// MARK: - Pure AppKit Loupe View

private class LoupeNSView: NSView {
    private let gridSize: Int
    private var currentImage: CGImage?
    private var currentColor: NSColor?
    private let cornerRadius: CGFloat = 12

    init(frame: NSRect, gridSize: Int) {
        self.gridSize = gridSize
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(image: CGImage?, centerColor: NSColor?) {
        currentImage = image
        currentColor = centerColor
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let loupeRect = NSRect(x: 0, y: bounds.height - bounds.width, width: bounds.width, height: bounds.width)
        let previewRect = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - bounds.width)

        // --- Loupe area ---
        ctx.saveGState()

        let loupePath = CGPath(roundedRect: loupeRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(loupePath)
        ctx.clip()

        if let img = currentImage {
            ctx.interpolationQuality = .none
            ctx.draw(img, in: loupeRect)
        } else {
            ctx.setFillColor(NSColor.windowBackgroundColor.cgColor)
            ctx.fill(loupeRect)
        }

        // Grid lines
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.1).cgColor)
        ctx.setLineWidth(0.5)
        let cellSize = loupeRect.width / CGFloat(gridSize)
        for i in 1..<gridSize {
            let pos = loupeRect.minX + CGFloat(i) * cellSize
            ctx.move(to: CGPoint(x: pos, y: loupeRect.minY))
            ctx.addLine(to: CGPoint(x: pos, y: loupeRect.maxY))
            let posY = loupeRect.minY + CGFloat(i) * cellSize
            ctx.move(to: CGPoint(x: loupeRect.minX, y: posY))
            ctx.addLine(to: CGPoint(x: loupeRect.maxX, y: posY))
        }
        ctx.strokePath()

        // Center pixel crosshair
        let centerX = loupeRect.midX
        let centerY = loupeRect.midY
        let halfCell = cellSize / 2
        let crosshairRect = CGRect(x: centerX - halfCell, y: centerY - halfCell, width: cellSize, height: cellSize)

        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(2)
        ctx.stroke(crosshairRect.insetBy(dx: -1, dy: -1))
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(crosshairRect.insetBy(dx: -2.5, dy: -2.5))

        // Loupe border
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.2).cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(loupePath)
        ctx.strokePath()

        ctx.restoreGState()

        // --- Color preview strip ---
        ctx.saveGState()

        let previewPath = CGPath(roundedRect: previewRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(previewPath)
        ctx.clip()
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
        ctx.fill(previewRect)

        // Color swatch
        let swatchSize: CGFloat = 24
        let swatchRect = CGRect(x: 10, y: previewRect.midY - swatchSize / 2, width: swatchSize, height: swatchSize)
        let swatchPath = CGPath(roundedRect: swatchRect, cornerWidth: 4, cornerHeight: 4, transform: nil)

        if let color = currentColor {
            ctx.addPath(swatchPath)
            ctx.setFillColor(color.cgColor)
            ctx.fillPath()
        }

        ctx.addPath(swatchPath)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()

        // Hex text
        if let color = currentColor {
            let srgb = color.usingColorSpace(.sRGB) ?? color
            let r = Int(round(srgb.redComponent * 255))
            let g = Int(round(srgb.greenComponent * 255))
            let b = Int(round(srgb.blueComponent * 255))
            let hex = String(format: "#%02X%02X%02X", r, g, b)

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let str = NSAttributedString(string: hex, attributes: attrs)
            let textOrigin = CGPoint(x: swatchRect.maxX + 10, y: previewRect.midY - str.size().height / 2)
            str.draw(at: textOrigin)
        }

        // Preview strip border
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.1).cgColor)
        ctx.setLineWidth(0.5)
        ctx.addPath(previewPath)
        ctx.strokePath()

        ctx.restoreGState()
    }
}
