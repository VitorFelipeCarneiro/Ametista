import Foundation
import AppKit

struct ClipboardItem: Identifiable, Equatable {

    enum Kind: Equatable {
        case text(String)
        case image(Data)     // PNG
        case fileURL(URL)    // arquivo copiado (Finder etc)
    }

    let id: UUID
    var date: Date
    var isPinned: Bool
    let kind: Kind

    init(id: UUID = UUID(), date: Date = Date(), isPinned: Bool = false, kind: Kind) {
        self.id = id
        self.date = date
        self.isPinned = isPinned
        self.kind = kind
    }

    var textValue: String? {
        if case .text(let t) = kind { return t }
        return nil
    }

    var imageData: Data? {
        if case .image(let d) = kind { return d }
        return nil
    }

    var fileURL: URL? {
        if case .fileURL(let u) = kind { return u }
        return nil
    }

    var nsImage: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    var displayTitle: String {
        switch kind {
        case .text(let t):
            return t
        case .image:
            return "Imagem"
        case .fileURL(let url):
            return url.lastPathComponent
        }
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
