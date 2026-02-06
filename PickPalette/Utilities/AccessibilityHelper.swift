import AppKit

/// Checks and requests accessibility permissions needed for global hotkeys.
enum AccessibilityHelper {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
