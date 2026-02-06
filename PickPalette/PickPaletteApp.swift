import SwiftUI

@main
struct PickPaletteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app — no main window.
        // The popover and settings are managed by the AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
