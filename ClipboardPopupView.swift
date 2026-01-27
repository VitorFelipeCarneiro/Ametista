import SwiftUI
import AppKit

struct ClipboardPopupView: View {
    @ObservedObject var store: ClipboardStore
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)

            VStack(spacing: 12) {
                header

                if store.items.isEmpty {
                    emptyState
                } else {
                    itemsList
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .frame(width: 360, height: 420)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 15, weight: .semibold))

            Text("Histórico do Ametista")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Nada copiado ainda.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var itemsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(store.items, id: \.id) { item in
                    Button {
                        store.copyToPasteboard(item)
                        onClose()
                    } label: {
                        itemRow(item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(item.isPinned ? "Desafixar" : "Fixar") {
                            store.togglePin(item)
                        }
                        Button("Copiar novamente") {
                            store.copyToPasteboard(item)
                        }
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func itemRow(_ item: ClipboardItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            iconForItem(item)
                .padding(.top, 2)

            // Conteúdo ocupa todo o espaço restante (evita sumir quando o texto é curto)
            contentForItem(item)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            Button {
                store.togglePin(item)
            } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.isPinned ? .primary : .secondary)
                    .frame(width: 26, height: 26)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private func iconForItem(_ item: ClipboardItem) -> some View {
        switch item.kind {
        case .text:
            return Image(systemName: "doc.text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

        case .image:
            return Image(systemName: "photo")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

        case .fileURL:
            return Image(systemName: "doc")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func contentForItem(_ item: ClipboardItem) -> some View {
        switch item.kind {
        case .text(let t):
            Text(verbatim: t.isEmpty ? " " : t)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)

        case .image(let pngData):
            if let image = NSImage(data: pngData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
                    .layoutPriority(1)
            } else {
                Text("Imagem")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

        case .fileURL(let url):
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(url.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
    }
}
