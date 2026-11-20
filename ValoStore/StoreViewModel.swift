import SwiftUI
import WebKit

@MainActor
final class StoreViewModel: ObservableObject {
    enum State {
        case needsLogin
        case loading
        case loaded(Dashboard)
        case failed(String)
    }

    @Published var state: State = .needsLogin
    @Published var shard: String {
        didSet { UserDefaults.standard.set(shard, forKey: "shard") }
    }

    init() {
        shard = UserDefaults.standard.string(forKey: "shard") ?? "eu"
        start()
    }

    func start() {
        if let token = Keychain.get("access"),
           let expString = Keychain.get("exp"),
           let exp = TimeInterval(expString),
           Date().timeIntervalSince1970 < exp - 60 {
            Task { await load(token: token) }
        } else {
            state = .needsLogin
        }
    }

    func didLogin(token: String, expiresIn: Int) {
        Keychain.set(token, for: "access")
        Keychain.set(String(Date().timeIntervalSince1970 + Double(expiresIn)), for: "exp")
        Task { await load(token: token) }
    }

    func refresh() async {
        guard let token = Keychain.get("access") else {
            state = .needsLogin
            return
        }
        await load(token: token)
    }

    private func load(token: String) async {
        var showSpinner = true
        if case .loaded = state { showSpinner = false }
        if showSpinner { state = .loading }
        do {
            let creds = try await RiotAPI.makeCreds(access: token, shard: shard)
            let catalog = try? await RiotAPI.catalog()
            async let store = RiotAPI.fetchStore(creds, catalog: catalog)
            async let wallet = try? RiotAPI.wallet(creds)
            async let inventory = RiotAPI.inventoryOrNil(creds, catalog)
            async let profile = RiotAPI.profile(creds)
            async let matches = try? RiotAPI.matches(creds)
            async let ranks = try? RiotAPI.rankHistory(creds)
            let s = try await store
            state = .loaded(Dashboard(
                skins: s.skins, remaining: s.remaining,
                night: s.night, nightRemaining: s.nightRemaining,
                wallet: await wallet, inventory: await inventory,
                profile: await profile, matches: await matches,
                rankPoints: await ranks))
        } catch RiotError.unauthorized {
            Keychain.delete("access")
            Keychain.delete("exp")
            state = .needsLogin
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func logout() {
        Keychain.delete("access")
        Keychain.delete("exp")
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) { }
        state = .needsLogin
    }
}
