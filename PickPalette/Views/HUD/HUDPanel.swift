import SwiftUI
import AppKit

/// Floating HUD panel — macOS Tahoe glass design.
final class HUDPanelController {
    private var panel: NSPanel?
    private var dismissTimer: Timer?

    func show(
        color: ColorModel,
        formattedValue: String,
        useGlassStyle: Bool,
        appearanceMode: AppearanceMode
    ) {
        dismiss()

        let hudView = HUDContentView(
            color: color,
            formattedValue: formattedValue,
            useGlassStyle: useGlassStyle,
            appearanceMode: appearanceMode,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: hudView)
        let contentSize = NSSize(width: 280, height: 72)
        hostingView.frame = NSRect(origin: .zero, size: contentSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position near top-center of the main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - contentSize.width / 2
            let y = screenFrame.maxY - 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // Animate in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        self.panel = panel

        // Auto-dismiss after 3.5 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.close()
            self?.panel = nil
        })
    }
}

// MARK: - HUD SwiftUI Content — Glass Tahoe Style

struct HUDContentView: View {
    let color: ColorModel
    let formattedValue: String
    let useGlassStyle: Bool
    let appearanceMode: AppearanceMode
    let onDismiss: () -> Void

    private var isDarkAppearance: Bool {
        switch appearanceMode {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color swatch with glow
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 38, height: 38)
                    .shadow(color: color.color.opacity(0.45), radius: 8)

                Circle()
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 38, height: 38)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(formattedValue)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isDarkAppearance ? .white : .primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 10))
                        .shadow(color: .green.opacity(0.4), radius: 4)
                    Text("Copied to Clipboard")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isDarkAppearance ? .white.opacity(0.55) : .secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 280, height: 72)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        useGlassStyle
                            ? AnyShapeStyle(isDarkAppearance ? .black.opacity(0.5) : .white.opacity(0.7))
                            : AnyShapeStyle(isDarkAppearance ? Color(white: 0.14) : Color(white: 0.96))
                    )

                if useGlassStyle {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .opacity(isDarkAppearance ? 0.4 : 0.55)
                }

                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isDarkAppearance ? .white.opacity(0.12) : .black.opacity(0.08),
                        lineWidth: 0.5
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            onDismiss()
        }
    }
}
