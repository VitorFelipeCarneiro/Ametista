import AppKit
import Foundation
import Combine

@MainActor
final class ClipboardStore: ObservableObject {

    struct KeyCombo: Equatable, Codable {
        var keyCode: UInt32
        var carbonModifiers: UInt32
        var display: String
    }

    struct Preferences: Equatable, Codable {
        var hotKey: KeyCombo
        var maxItems: Int
        var launchAtLogin: Bool
    }

    @Published private(set) var items: [ClipboardItem] = []

    @Published private(set) var preferences: Preferences {
        didSet {
            savePreferences()
            onPreferencesChanged?(preferences)
        }
    }

    var onPreferencesChanged: ((Preferences) -> Void)?

    private let defaults = UserDefaults.standard
    private let prefsKey = "clipboardstore.preferences.v1"

    init() {
        if let data = defaults.data(forKey: prefsKey),
           let decoded = try? JSONDecoder().decode(Preferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = Preferences(
                hotKey: KeyCombo(keyCode: 49, carbonModifiers: 0, display: "Space"),
                maxItems: 10,
                launchAtLogin: false
            )
        }
    }

    func updateHotKey(_ combo: KeyCombo) {
        preferences.hotKey = combo
    }

    func updateMaxItems(_ value: Int) {
        preferences.maxItems = value
        pruneToMaxItems()
    }

    func updateLaunchAtLogin(_ value: Bool) {
        preferences.launchAtLogin = value
    }

    func add(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        upsert(kind: .text(trimmed))
    }

    func addImage(pngData: Data) {
        guard pngData.isEmpty == false else { return }
        upsert(kind: .image(pngData))
    }

    func addFileURL(_ url: URL) {
        if let png = url.pngDataIfImageFile(), png.isEmpty == false {
            upsert(kind: .image(png))
            return
        }
        upsert(kind: .fileURL(url))
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isPinned.toggle()
        items[idx].date = Date()
        normalizeOrder()
        pruneToMaxItems()
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.kind {
        case .text(let t):
            pb.setString(t, forType: .string)

        case .image(let png):
            if let img = NSImage(data: png) {
                writeImageToPasteboard(img, png: png, pb: pb)
            } else {
                pb.setData(png, forType: .png)
            }

        case .fileURL(let url):
            // Se for imagem, cola como imagem, não como nome do arquivo
            if let png = url.pngDataIfImageFile(),
               let img = NSImage(data: png) {
                writeImageToPasteboard(img, png: png, pb: pb)
            } else {
                pb.writeObjects([url as NSURL])
            }
        }

        bumpToTopIfNeeded(item)
    }

    private func writeImageToPasteboard(_ image: NSImage, png: Data?, pb: NSPasteboard) {
        // Declara tipos comuns para colagem em apps diferentes
        pb.declareTypes([.tiff, .png], owner: nil)

        if let tiff = image.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }

        if let png, png.isEmpty == false {
            pb.setData(png, forType: .png)
        } else if let png2 = image.pngData() {
            pb.setData(png2, forType: .png)
        }

        // Também escreve como objeto, ajuda em alguns apps
        pb.writeObjects([image])
    }

    private func bumpToTopIfNeeded(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].date = Date()
        normalizeOrder()
        pruneToMaxItems()
    }

    private func upsert(kind: ClipboardItem.Kind) {
        if let existingIndex = findExisting(kind: kind) {
            items[existingIndex].date = Date()
            normalizeOrder()
            pruneToMaxItems()
            return
        }

        let newItem = ClipboardItem(kind: kind)
        items.append(newItem)
        normalizeOrder()
        pruneToMaxItems()
    }

    private func findExisting(kind: ClipboardItem.Kind) -> Int? {
        switch kind {
        case .text(let t):
            return items.firstIndex { item in
                if case .text(let other) = item.kind { return other == t }
                return false
            }

        case .image(let d):
            return items.firstIndex { item in
                if case .image(let other) = item.kind { return other == d }
                return false
            }

        case .fileURL(let u):
            return items.firstIndex { item in
                if case .fileURL(let other) = item.kind { return other == u }
                return false
            }
        }
    }

    private func normalizeOrder() {
        items.sort { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.date > b.date
        }
    }

    private func pruneToMaxItems() {
        let maxItems = Swift.max(preferences.maxItems, 1)

        let pinned = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }

        let remaining = Swift.max(maxItems - pinned.count, 0)
        let trimmedUnpinned = Array(unpinned.prefix(remaining))

        items = pinned + trimmedUnpinned
        normalizeOrder()
    }

    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: prefsKey)
        }
    }
}

private extension URL {
    func pngDataIfImageFile() -> Data? {
        let ext = self.pathExtension.lowercased()
        let known = ["png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "tif", "bmp", "webp"]
        guard known.contains(ext) else { return nil }

        guard let image = NSImage(contentsOf: self) else { return nil }
        return image.pngData()
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
