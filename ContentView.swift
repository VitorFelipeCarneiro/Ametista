import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Clipboard History")
                .font(.title2)
                .fontWeight(.semibold)

            Text("O app roda na barra superior. Use o ícone ou o atalho para abrir o histórico.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(16)
        .frame(width: 420, height: 220)
    }
}
