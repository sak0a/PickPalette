import AppKit
import Carbon

/// Manages a global hotkey registration using the Carbon API.
/// Supports custom key code and modifier combinations.
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    /// Register a global hotkey with the given Carbon key code and modifier flags.
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        // Unregister any existing hotkey first
        unregister()

        self.handler = handler

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x5050_4B48) // "PPKH"
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        // Install handler (only if not already installed)
        if eventHandlerRef == nil {
            let selfPtr = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData -> OSStatus in
                    guard let userData else { return OSStatus(eventNotHandledErr) }
                    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    manager.handler?()
                    return noErr
                },
                1,
                &eventType,
                selfPtr,
                &eventHandlerRef
            )
        }

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit {
        unregister()
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
        }
    }
}

// MARK: - Key Code / Modifier Helpers

extension GlobalHotkeyManager {

    /// Maps a Carbon key code to a human-readable key name.
    static func keyName(for keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
            0x2F: ".", 0x30: "Tab", 0x31: "Space", 0x32: "`",
            0x24: "Return", 0x33: "Delete", 0x35: "Escape",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        return map[keyCode] ?? "Key \(keyCode)"
    }

    /// Converts Carbon modifier flags to an array of symbol strings.
    static func modifierSymbols(for modifiers: UInt32) -> [String] {
        var symbols: [String] = []
        if modifiers & UInt32(controlKey) != 0 { symbols.append("\u{2303}") }  // ⌃
        if modifiers & UInt32(optionKey)  != 0 { symbols.append("\u{2325}") }  // ⌥
        if modifiers & UInt32(shiftKey)   != 0 { symbols.append("\u{21E7}") }  // ⇧
        if modifiers & UInt32(cmdKey)     != 0 { symbols.append("\u{2318}") }  // ⌘
        return symbols
    }

    /// Converts an NSEvent.ModifierFlags to Carbon modifier UInt32.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey)  }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey)   }
        if flags.contains(.command) { carbon |= UInt32(cmdKey)     }
        return carbon
    }

    /// Full display string like "⌥⇧C".
    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        let mods = modifierSymbols(for: modifiers).joined()
        let key = keyName(for: keyCode)
        return mods + key
    }
}
