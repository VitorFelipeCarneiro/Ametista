import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private let store = ClipboardStore()
    private let watcher = ClipboardWatcher()
    private let panel = FloatingPanelController()

    private var hotKey: GlobalHotKeyManager?
    private var settingsWC: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        watcher.start { [weak self] payload in
            Task { @MainActor in
                guard let self else { return }
                switch payload {
                case .text(let text):
                    self.store.add(text: text)

                case .image(let png):
                    self.store.addImage(pngData: png)

                case .fileURL(let url):
                    self.store.addFileURL(url)
                }
            }
        }

        hotKey = GlobalHotKeyManager { [weak self] in
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                self?.togglePopupAtMouse()
            }
        }

        applyHotKeyFromPreferences()

        store.onPreferencesChanged = { [weak self] (_: ClipboardStore.Preferences) in
            self?.applyHotKeyFromPreferences()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher.stop()
        panel.dismiss()
        hotKey?.stop()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        panel.attachStatusItem(item)

        if let button = item.button {
            let image = NSImage(named: "StatusIcon")
            image?.isTemplate = true   // importante para dark/light mode
            button.image = image
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Abrir histórico",
            action: #selector(showFromStatusItem),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Configurações…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Sair",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        item.menu = menu
    }

    @objc private func showFromStatusItem() {
        NSApp.activate(ignoringOtherApps: true)
        let view = makePopupView()
        panel.toggleAnchored(view: view)
    }

    @objc private func openSettings() {
        if settingsWC == nil {
            settingsWC = SettingsWindowController(store: store)
        }
        settingsWC?.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func makePopupView() -> ClipboardPopupView {
        ClipboardPopupView(
            store: store,
            onClose: { [weak self] in
                self?.panel.dismiss()
            }
        )
    }

    private func togglePopupAtMouse() {
        let view = makePopupView()
        let mouse = NSEvent.mouseLocation
        panel.toggleAtMouse(view: view, screenPoint: mouse)
    }

    private func applyHotKeyFromPreferences() {
        let combo = store.preferences.hotKey
        hotKey?.start(
            keyCode: combo.keyCode,
            modifiers: combo.carbonModifiers
        )
    }
}
