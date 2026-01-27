import AppKit
import Foundation

final class ClipboardWatcher {

    enum Payload {
        case text(String)
        case image(Data)     // PNG
        case fileURL(URL)
    }

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    func start(onChange: @escaping (Payload) -> Void) {
        stop()

        lastChangeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            guard let self else { return }
            let cc = self.pasteboard.changeCount
            guard cc != self.lastChangeCount else { return }
            self.lastChangeCount = cc

            if let payload = self.readPayload() {
                onChange(payload)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func readPayload() -> Payload? {
        // 1) Primeiro tenta URL de arquivo
        if let url = readFileURLFromPasteboard() {
            if let png = url.pngDataIfImageFile(), png.isEmpty == false {
                return .image(png)
            }
            return .fileURL(url)
        }

        // 2) Depois tenta imagem
        if let png = pasteboard.data(forType: .png), png.isEmpty == false {
            return .image(png)
        }

        if let tiff = pasteboard.data(forType: .tiff),
           let img = NSImage(data: tiff),
           let png = img.pngData(),
           png.isEmpty == false {
            return .image(png)
        }

        if let img = NSImage(pasteboard: pasteboard),
           let png = img.pngData(),
           png.isEmpty == false {
            return .image(png)
        }

        // 3) Texto por último, mas agora tentando também RTF e HTML
        if let text = readTextFromPasteboard() {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return .text(trimmed)
            }
        }

        return nil
    }

    private func readTextFromPasteboard() -> String? {
        // Texto simples
        if let str = pasteboard.string(forType: .string), str.isEmpty == false {
            return str
        }

        // RTF
        if let data = pasteboard.data(forType: .rtf) {
            if let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                let s = attributed.string
                if s.isEmpty == false { return s }
            }
        }

        // HTML
        if let data = pasteboard.data(forType: .html) {
            if let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
            ) {
                let s = attributed.string
                if s.isEmpty == false { return s }
            }
        }

        // Fallback usando itens do pasteboard
        for item in pasteboard.pasteboardItems ?? [] {
            if let s = item.string(forType: .string), s.isEmpty == false { return s }
            if let data = item.data(forType: .rtf),
               let attributed = try? NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
               ) {
                let s = attributed.string
                if s.isEmpty == false { return s }
            }
            if let data = item.data(forType: .html),
               let attributed = try? NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.html,
                              .characterEncoding: String.Encoding.utf8.rawValue],
                    documentAttributes: nil
               ) {
                let s = attributed.string
                if s.isEmpty == false { return s }
            }
        }

        return nil
    }

    private func readFileURLFromPasteboard() -> URL? {
        if let objs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil),
           let nsurl = objs.first as? NSURL,
           let url = nsurl as URL? {
            return url
        }

        if let fileURLString = pasteboard.string(forType: .fileURL),
           let url = URL(string: fileURLString) {
            return url
        }

        return nil
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
