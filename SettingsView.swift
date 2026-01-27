import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {

    @ObservedObject var store: ClipboardStore
    @State private var isRecording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Configurações")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 2)

            GroupBox {
                HStack(spacing: 12) {
                    Text("Atual:")
                    Text(store.preferences.hotKey.display)
                        .fontWeight(.semibold)

                    Spacer()

                    Button(isRecording ? "Pressione o atalho…" : "Alterar") {
                        isRecording.toggle()
                    }
                    .keyboardShortcut(.defaultAction)

                    if isRecording {
                        HotKeyRecorder { combo in
                            store.updateHotKey(combo)
                            isRecording = false
                        } onCancel: {
                            isRecording = false
                        }
                        .frame(width: 0, height: 0)
                    }
                }
                .padding(8)
            } label: {
                Text("Atalho do teclado")
            }

            GroupBox {
                HStack {
                    Text("Limite máximo de itens")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { store.preferences.maxItems },
                        set: { store.updateMaxItems($0) }
                    )) {
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("15").tag(15)
                        Text("20").tag(20)
                    }
                    .frame(width: 120)
                }
                .padding(8)
            } label: {
                Text("Histórico")
            }

            GroupBox {
                Toggle("Iniciar com o macOS", isOn: Binding(
                    get: { store.preferences.launchAtLogin },
                    set: { store.updateLaunchAtLogin($0) }
                ))
                .padding(8)
            } label: {
                Text("Inicialização")
            }
        }
        .padding(18)
        .padding(.bottom, 10)
    }
}

private struct HotKeyRecorder: NSViewRepresentable {

    let onCapture: (ClipboardStore.KeyCombo) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        context.coordinator.installMonitor(onCapture: onCapture, onCancel: onCancel)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var localMonitor: Any?

        func installMonitor(onCapture: @escaping (ClipboardStore.KeyCombo) -> Void,
                            onCancel: @escaping () -> Void) {
            removeMonitor()

            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
                if event.type == .keyDown {
                    if event.keyCode == 53 {
                        onCancel()
                        self.removeMonitor()
                        return nil
                    }

                    let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
                    let carbon = Self.carbonModifiers(from: flags)
                    let display = Self.displayString(for: event, flags: flags)

                    let combo = ClipboardStore.KeyCombo(
                        keyCode: UInt32(event.keyCode),
                        carbonModifiers: carbon,
                        display: display
                    )

                    onCapture(combo)
                    self.removeMonitor()
                    return nil
                }

                return event
            }
        }

        func removeMonitor() {
            if let m = localMonitor {
                NSEvent.removeMonitor(m)
                localMonitor = nil
            }
        }

        private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var carbon: UInt32 = 0
            if flags.contains(.command) { carbon |= UInt32(cmdKey) }
            if flags.contains(.option) { carbon |= UInt32(optionKey) }
            if flags.contains(.control) { carbon |= UInt32(controlKey) }
            if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
            return carbon
        }

        private static func displayString(for event: NSEvent, flags: NSEvent.ModifierFlags) -> String {
            var parts: [String] = []

            if flags.contains(.control) { parts.append("⌃") }
            if flags.contains(.option) { parts.append("⌥") }
            if flags.contains(.shift) { parts.append("⇧") }
            if flags.contains(.command) { parts.append("⌘") }

            parts.append(humanKey(event))
            return parts.joined(separator: " ")
        }

        private static func humanKey(_ event: NSEvent) -> String {
            switch Int(event.keyCode) {
            case kVK_Space: return "Space"
            case kVK_Return: return "Return"
            case kVK_Tab: return "Tab"
            case kVK_Delete: return "Delete"
            case kVK_Escape: return "Esc"
            case kVK_LeftArrow: return "←"
            case kVK_RightArrow: return "→"
            case kVK_UpArrow: return "↑"
            case kVK_DownArrow: return "↓"
            default:
                if let chars = event.charactersIgnoringModifiers, chars.isEmpty == false {
                    return chars.uppercased()
                }
                return "Key \(event.keyCode)"
            }
        }
    }
}
