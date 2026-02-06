import AppKit
import SwiftUI

/// AppDelegate manages the menu bar icon, popover, HUD panel, and global hotkey.
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let appState = AppState()
    private let hudController = HUDPanelController()
    private var settingsWindow: NSWindow?
    private var eventMonitor: Any?
    private var statusMenu: NSMenu!
    private var eyedropperController: EyedropperController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.load()

        setupStatusItem()
        setupPopover()
        setupStatusMenu()
        setupGlobalHotkey()
        setupEventMonitor()

        // Apply appearance
        NSApp.appearance = appState.appearance.nsAppearance

        // Check accessibility on first launch
        if !AccessibilityHelper.isTrusted {
            AccessibilityHelper.requestAccess()
        }

        // Show onboarding on first launch
        if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showPopover()
            }
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paintpalette.fill", accessibilityDescription: "PickPalette")
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    private func setupStatusMenu() {
        statusMenu = NSMenu()
        statusMenu.addItem(withTitle: "Pick Color", action: #selector(pickColorAction), keyEquivalent: "")
        statusMenu.addItem(.separator())
        statusMenu.addItem(withTitle: "Settings...", action: #selector(openSettingsAction), keyEquivalent: ",")
        statusMenu.addItem(.separator())
        statusMenu.addItem(withTitle: "Quit PickPalette", action: #selector(quitAction), keyEquivalent: "q")
        for item in statusMenu.items {
            item.target = self
        }
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            // Show the context menu manually at the status item location
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            // Must reset menu asynchronously so left click still triggers action next time
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
            }
        } else {
            togglePopover()
        }
    }

    @objc private func pickColorAction() {
        pickColor()
    }

    @objc private func openSettingsAction() {
        openSettings()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        updatePopoverContent()
    }

    /// Rebuilds the popover content view — call whenever appState needs a fresh binding.
    private func updatePopoverContent() {
        let contentView = PopoverContentView(
            appState: appState,
            onOpenSettings: { [weak self] in
                self?.popover.close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.openSettings()
                }
            },
            onEyedropper: { [weak self] in
                self?.popover.close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.pickColor()
                }
            }
        )
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    // NSPopoverDelegate — no-op; @Observable keeps the view in sync automatically.
    // Rebuilding rootView here causes _NSDetectedLayoutRecursion when SwiftUI is still tearing down.
    nonisolated func popoverDidClose(_ notification: Notification) {
        // intentionally empty
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func togglePopover() {
        if popover.isShown {
            popover.close()
        } else {
            showPopover()
        }
    }

    // MARK: - Click-away to close

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            if self.popover.isShown {
                self.popover.close()
            }
        }
    }

    // MARK: - Eyedropper

    private func pickColor() {
        let controller = EyedropperController()
        self.eyedropperController = controller
        controller.start { [weak self] pickedColor in
            guard let self else { return }
            self.eyedropperController = nil
            guard let pickedColor else { return }

            let model = ColorModel(nsColor: pickedColor)
            self.appState.currentColor = model
            self.appState.addToRecent(model)
            self.appState.copyColor()

            if self.appState.showHUDAfterPick {
                let formatted = self.appState.defaultFormat.format(color: model)
                self.hudController.show(color: model, formattedValue: formatted)
            }
        }
    }

    // MARK: - Global Hotkey

    private func setupGlobalHotkey() {
        registerHotkey()

        // Listen for hotkey trigger via notification (used both by initial registration and re-registration from settings)
        NotificationCenter.default.addObserver(
            forName: .pickColorHotkey,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pickColor()
        }
    }

    /// Registers the global hotkey with current appState values.
    private func registerHotkey() {
        GlobalHotkeyManager.shared.register(
            keyCode: appState.hotkeyKeyCode,
            modifiers: appState.hotkeyModifiers
        ) {
            NotificationCenter.default.post(name: .pickColorHotkey, object: nil)
        }
    }

    // MARK: - Settings Window

    private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(appState: appState)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "PickPalette Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92)
        window.setContentSize(NSSize(width: 600, height: 480))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window.isReleasedWhenClosed = false
        self.settingsWindow = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.save()
        GlobalHotkeyManager.shared.unregister()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
