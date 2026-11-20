import SwiftUI

struct ContentView: View {
    @StateObject private var vm = StoreViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .needsLogin:
                    LoginView { token, expires in
                        vm.didLogin(token: token, expiresIn: expires)
                    }
                case .loading:
                    ProgressView("Mağaza yükleniyor…")
                case .loaded(let skins, let remaining):
                    List {
                        Section(header: Text("Yenilenmesine: \(formatRemaining(remaining))")) {
                            ForEach(skins) { skin in
                                SkinRow(skin: skin)
                            }
                        }
                    }
                    .refreshable { await vm.refresh() }
                case .failed(let message):
                    VStack(spacing: 16) {
                        Text(message).multilineTextAlignment(.center)
                        Button("Tekrar dene") { Task { await vm.refresh() } }
                        Button("Çıkış yap") { vm.logout() }
                    }
                    .padding()
                }
            }
            .navigationTitle("Valorant Mağaza")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Bölge", selection: $vm.shard) {
                            ForEach(["eu", "na", "ap", "kr"], id: \.self) { s in
                                Text(s.uppercased()).tag(s)
                            }
                        }
                        Button("Çıkış yap", role: .destructive) { vm.logout() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onChange(of: vm.shard) { _ in
                Task { await vm.refresh() }
            }
        }
    }

    private func formatRemaining(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h) sa \(m) dk" : "\(m) dk"
    }
}

struct SkinRow: View {
    let skin: Skin

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: skin.icon) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.15)
            }
            .frame(width: 110, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(skin.name).font(.headline)
                if let price = skin.price {
                    Text("\(price) VP").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
