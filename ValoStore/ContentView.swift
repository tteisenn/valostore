import SwiftUI

struct ContentView: View {
    @StateObject private var vm = StoreViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch vm.state {
                case .needsLogin:
                    NavigationStack {
                        LoginView { token, expires in
                            vm.didLogin(token: token, expiresIn: expires)
                        }
                        .navigationTitle("Giriş")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                case .loading:
                    ProgressView("Yükleniyor…")
                case .failed(let message):
                    VStack(spacing: 16) {
                        Text(message).multilineTextAlignment(.center)
                        Button("Tekrar dene") { Task { await vm.refresh() } }
                        Button("Çıkış yap") { vm.logout() }
                    }
                    .padding()
                case .loaded(let d):
                    TabView {
                        StoreTab(d: d, vm: vm)
                            .tabItem { Label("Mağaza", systemImage: "cart") }
                        InventoryTab(items: d.inventory, vm: vm)
                            .tabItem { Label("Envanter", systemImage: "square.grid.2x2") }
                        MatchesTab(matches: d.matches, points: d.rankPoints, vm: vm)
                            .tabItem { Label("Maçlar", systemImage: "chart.line.uptrend.xyaxis") }
                        ProfileTab(profile: d.profile, wallet: d.wallet, vm: vm)
                            .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("developed by fortegod")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .onChange(of: vm.shard) { _ in
            Task { await vm.refresh() }
        }
    }
}

extension View {
    func appMenu(_ vm: StoreViewModel) -> some View {
        toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Bölge", selection: Binding(get: { vm.shard }, set: { vm.shard = $0 })) {
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
    }
}

struct WalletRow: View {
    let wallet: Wallet
    var body: some View {
        HStack {
            Spacer()
            VStack { Text("\(wallet.vp)").font(.headline); Text("VP").font(.caption).foregroundStyle(.secondary) }
            Spacer()
            VStack { Text("\(wallet.rp)").font(.headline); Text("Radyanit").font(.caption).foregroundStyle(.secondary) }
            Spacer()
            VStack { Text("\(wallet.kc)").font(.headline); Text("KC").font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }
    }
}

struct StoreTab: View {
    let d: Dashboard
    let vm: StoreViewModel
    var body: some View {
        NavigationStack {
            List {
                if let w = d.wallet {
                    Section("Bakiye") { WalletRow(wallet: w) }
                }
                Section("Günlük mağaza · \(fmt(d.remaining))") {
                    ForEach(d.skins) { s in
                        NavigationLink { SkinDetail(skin: s) } label: { SkinRow(skin: s) }
                    }
                }
                if !d.night.isEmpty {
                    Section("Gece Pazarı · \(fmt(d.nightRemaining ?? 0))") {
                        ForEach(d.night) { s in
                            NavigationLink { SkinDetail(skin: s) } label: { SkinRow(skin: s) }
                        }
                    }
                }
            }
            .refreshable { await vm.refresh() }
            .navigationTitle("Mağaza")
            .appMenu(vm)
        }
    }
    private func fmt(_ s: Int) -> String {
        let days = s / 86400
        let h = (s % 86400) / 3600
        let m = (s % 3600) / 60
        if days > 0 { return "\(days) g \(h) sa" }
        return h > 0 ? "\(h) sa \(m) dk" : "\(m) dk"
    }
}

struct InventoryTab: View {
    let items: [Skin]?
    let vm: StoreViewModel
    @State private var query = ""
    @State private var weapon = "Tümü"

    var body: some View {
        NavigationStack {
            Group {
                if let items = items {
                    let weapons = ["Tümü"] + Array(Set(items.compactMap { $0.weapon })).sorted()
                    let shown = items.filter { s in
                        (weapon == "Tümü" || s.weapon == weapon) &&
                        (query.isEmpty || s.name.localizedCaseInsensitiveContains(query))
                    }
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(weapons, id: \.self) { w in
                                    Button(w) { weapon = w }
                                        .buttonStyle(.bordered)
                                        .tint(w == weapon ? Color.accentColor : Color.gray)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                        List(shown) { s in
                            NavigationLink { SkinDetail(skin: s) } label: { SkinRow(skin: s) }
                        }
                    }
                    .searchable(text: $query, prompt: "Skin ara")
                    .navigationTitle("Envanter (\(shown.count)/\(items.count))")
                } else {
                    Text("Envanter yüklenemedi.")
                        .navigationTitle("Envanter")
                }
            }
            .appMenu(vm)
        }
    }
}

struct ProfileTab: View {
    let profile: Profile?
    let wallet: Wallet?
    let vm: StoreViewModel
    var body: some View {
        NavigationStack {
            ScrollView {
                if let p = profile {
                    VStack(spacing: 14) {
                        AsyncImage(url: p.cardURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.gray.opacity(0.15)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text(p.name).font(.title2).bold()
                        if let t = p.title { Text(t).foregroundStyle(.secondary) }
                        if let lvl = p.level { Text("Seviye \(lvl)") }
                        HStack(spacing: 8) {
                            AsyncImage(url: p.rankIcon) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Color.clear
                            }
                            .frame(width: 40, height: 40)
                            VStack(alignment: .leading) {
                                Text(p.rank).font(.headline)
                                if let rr = p.rr { Text("\(rr) RR").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        if let w = wallet { WalletRow(wallet: w).padding(.top, 8) }
                    }
                    .padding()
                } else {
                    Text("Profil yüklenemedi.").padding()
                }
            }
            .refreshable { await vm.refresh() }
            .navigationTitle("Profil")
            .appMenu(vm)
        }
    }
}
