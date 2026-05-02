import AppKit
import SwiftUI

/// AppDelegate manages the menu bar icon, popover, HUD panel, and global hotkey.
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let appState = AppState()
    private let hudController = HUDPanelController()
    private var settingsWindow: NSWindow?
    private var editorWindow: NSWindow?
    private var eventMonitor: Any?
    private var statusMenu: NSMenu!
    private var eyedropperController: EyedropperController?
    private var windowCloseObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.load()

        setupStatusItem()
        setupPopover()
        setupStatusMenu()
        setupGlobalHotkey()
        setupEventMonitor()

        // Apply appearance
        NSApp.appearance = appState.appearance.nsAppearance

        // Listen for layout editor notification from Settings
        NotificationCenter.default.addObserver(
            forName: .openLayoutEditor,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openLayoutEditor()
        }

        // Observe window close to hide Dock icon when all windows are closed
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let closingWindow = notification.object as? NSWindow,
                  closingWindow === self.settingsWindow || closingWindow === self.editorWindow else { return }
            // Check after a short delay so the window state is updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.checkAndHideDock()
            }
        }

        // Check accessibility on first launch
        if !AccessibilityHelper.isTrusted {
            AccessibilityHelper.requestAccess()
        }

        // Check for updates after a short delay (non-blocking)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UpdateChecker.checkForUpdates()
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
        statusMenu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdatesAction), keyEquivalent: "")
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

    @objc private func checkForUpdatesAction() {
        UpdateChecker.checkForUpdates(manual: true)
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
            },
            onEditLayout: { [weak self] in
                self?.popover.close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.openLayoutEditor()
                }
            }
        )
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.appearance = appState.appearance.nsAppearance
        popover.contentViewController = hostingController
    }

    // NSPopoverDelegate — no-op; @Observable keeps the view in sync automatically.
    // Rebuilding rootView here causes _NSDetectedLayoutRecursion when SwiftUI is still tearing down.
    nonisolated func popoverDidClose(_ notification: Notification) {
        // intentionally empty
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.appearance = appState.appearance.nsAppearance
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
                self.hudController.show(
                    color: model,
                    formattedValue: formatted,
                    useGlassStyle: self.appState.effectiveGlassStyle,
                    appearanceMode: self.appState.appearance
                )
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

        // Show app in Dock when a window is open
        showInDock()

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

    // MARK: - Layout Editor Window

    private func openLayoutEditor() {
        if let window = editorWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Show app in Dock when a window is open
        showInDock()

        let editorView = LayoutEditorView(appState: appState) { [weak self] in
            self?.editorWindow?.close()
        }
        let hostingController = NSHostingController(rootView: editorView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Edit Layout"
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor.windowBackgroundColor
        window.setContentSize(NSSize(width: 800, height: 650))
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window.isReleasedWhenClosed = false
        self.editorWindow = window
    }

    // MARK: - Dock Visibility

    /// Shows the app icon in the Dock (switches from accessory to regular).
    private func showInDock() {
        NSApp.setActivationPolicy(.regular)
    }

    /// Hides the app from the Dock if no windows are visible (switches back to accessory).
    private func checkAndHideDock() {
        let settingsVisible = settingsWindow?.isVisible ?? false
        let editorVisible = editorWindow?.isVisible ?? false
        if !settingsVisible && !editorVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.save()
        GlobalHotkeyManager.shared.unregister()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
