import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {

    convenience init(store: ClipboardStore) {
        let view = SettingsView(store: store)
        let hosting = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Configurações"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = hosting

        self.init(window: window)
    }

    func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
