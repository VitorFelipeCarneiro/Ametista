import AppKit
import SwiftUI

final class FloatingPanelController {

    var onDismiss: (() -> Void)?

    private var panel: GlassPanel?
    private weak var statusItem: NSStatusItem?

    private var globalMouseMonitor: Any?
    private var globalRightMouseMonitor: Any?

    deinit {
        stopMonitors()
    }

    func attachStatusItem(_ item: NSStatusItem) {
        statusItem = item
    }

    func isVisible() -> Bool {
        panel?.isVisible ?? false
    }

    func dismiss() {
        if Thread.isMainThread {
            dismissOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.dismissOnMain()
            }
        }
    }

    private func dismissOnMain() {
        stopMonitors()
        panel?.orderOut(nil)
        onDismiss?()
    }

    func toggleAnchored(view: ClipboardPopupView) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isVisible() {
                self.dismissOnMain()
                return
            }
            self.showAnchored(view: view)
        }
    }

    func toggleAtMouse(view: ClipboardPopupView) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isVisible() {
                self.dismissOnMain()
                return
            }
            self.showAtPoint(view: view, screenPoint: NSEvent.mouseLocation)
        }
    }

    func toggleAtMouse(view: ClipboardPopupView, screenPoint: NSPoint) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isVisible() {
                self.dismissOnMain()
                return
            }
            self.showAtPoint(view: view, screenPoint: screenPoint)
        }
    }

    private func showAnchored(view: ClipboardPopupView) {
        ensurePanel(view: view)

        guard let panel else { return }

        guard let button = statusItem?.button else {
            showAtPoint(view: view, screenPoint: NSEvent.mouseLocation)
            return
        }

        let buttonRectOnScreen =
            button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero

        let preferredX = buttonRectOnScreen.midX - panel.frame.width / 2
        let preferredY = buttonRectOnScreen.minY - panel.frame.height - 8

        let origin = clampToVisibleScreen(
            NSPoint(x: preferredX, y: preferredY),
            panelSize: panel.frame.size,
            referencePoint: NSPoint(x: buttonRectOnScreen.midX, y: buttonRectOnScreen.midY)
        )

        panel.setFrameOrigin(origin)
        present(panel: panel)
    }

    private func showAtPoint(view: ClipboardPopupView, screenPoint: NSPoint) {
        ensurePanel(view: view)

        guard let panel else { return }

        let preferredX = screenPoint.x - panel.frame.width / 2
        let preferredY = screenPoint.y - panel.frame.height - 12

        let origin = clampToVisibleScreen(
            NSPoint(x: preferredX, y: preferredY),
            panelSize: panel.frame.size,
            referencePoint: screenPoint
        )

        panel.setFrameOrigin(origin)
        present(panel: panel)
    }

    private func present(panel: GlassPanel) {
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        startMonitors()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    private func ensurePanel(view: ClipboardPopupView) {
        if let panel {
            panel.contentView = NSHostingView(rootView: view)
            return
        }

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 360, height: 420)

        let p = GlassPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        p.level = .floating
        p.hasShadow = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = true

        p.contentView = hosting
        panel = p
    }

    private func startMonitors() {
        stopMonitors()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.dismiss()
        }

        globalRightMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
    }

    private func stopMonitors() {
        if let m = globalMouseMonitor {
            NSEvent.removeMonitor(m)
            globalMouseMonitor = nil
        }
        if let m = globalRightMouseMonitor {
            NSEvent.removeMonitor(m)
            globalRightMouseMonitor = nil
        }
    }

    private func clampToVisibleScreen(_ origin: NSPoint, panelSize: NSSize, referencePoint: NSPoint) -> NSPoint {
        let screens = NSScreen.screens
        let targetScreen = screens.first(where: { $0.frame.contains(referencePoint) }) ?? NSScreen.main
        let visible = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 700)

        var x = origin.x
        var y = origin.y

        if x + panelSize.width > visible.maxX { x = visible.maxX - panelSize.width - 8 }
        if x < visible.minX { x = visible.minX + 8 }

        if y + panelSize.height > visible.maxY { y = visible.maxY - panelSize.height - 8 }
        if y < visible.minY { y = visible.minY + 8 }

        return NSPoint(x: x, y: y)
    }
}

final class GlassPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }
}
