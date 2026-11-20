import Foundation

enum RiotError: LocalizedError {
    case unauthorized
    case http(Int)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Oturum süresi doldu. Tekrar giriş yap."
        case .http(let code): return "Sunucu hatası (HTTP \(code))."
        case .other(let msg): return msg
        }
    }
}

struct Skin: Identifiable {
    let id: String
    let name: String
    let icon: URL?
    let price: Int?
}

enum RiotAPI {
    static let vpCurrency = "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741"

    static let authorizeURL = URL(string:
        "https://auth.riotgames.com/authorize?redirect_uri=https%3A%2F%2Fplayvalorant.com%2Fopt_in&client_id=play-valorant-web-prod&response_type=token%20id_token&nonce=1&scope=account%20openid"
    )!

    // MARK: - Public

    static func fetchStore(accessToken: String, shard: String) async throws -> (skins: [Skin], remaining: Int) {
        let version = try await clientVersion()
        let entitlement = try await fetchEntitlement(access: accessToken)
        let puuid = try await fetchPUUID(access: accessToken)
        let panel = try await storefront(access: accessToken, entitlement: entitlement,
                                         version: version, shard: shard, puuid: puuid)

        var skins: [Skin] = []
        for uuid in panel.SingleItemOffers {
            let info = try? await skinInfo(uuid)
            let price = panel.SingleItemStoreOffers?
                .first(where: { $0.OfferID == uuid })?.Cost[vpCurrency]
            skins.append(Skin(
                id: uuid,
                name: info?.displayName ?? uuid,
                icon: info?.displayIcon.flatMap { URL(string: $0) },
                price: price
            ))
        }
        return (skins, panel.SingleItemOffersRemainingDurationInSeconds)
    }

    // MARK: - Models

    struct StorefrontResponse: Decodable {
        let SkinsPanelLayout: SkinsPanel
    }
    struct SkinsPanel: Decodable {
        let SingleItemOffers: [String]
        let SingleItemOffersRemainingDurationInSeconds: Int
        let SingleItemStoreOffers: [StoreOffer]?
    }
    struct StoreOffer: Decodable {
        let OfferID: String
        let Cost: [String: Int]
    }
    struct SkinLevelResponse: Decodable {
        struct Item: Decodable {
            let displayName: String
            let displayIcon: String?
        }
        let data: Item
    }

    // MARK: - Calls

    private static func clientVersion() async throws -> String {
        struct R: Decodable {
            struct D: Decodable { let riotClientVersion: String }
            let data: D
        }
        let req = URLRequest(url: URL(string: "https://valorant-api.com/v1/version")!)
        let data = try await send(req)
        return try JSONDecoder().decode(R.self, from: data).data.riotClientVersion
    }

    private static func fetchEntitlement(access: String) async throws -> String {
        struct R: Decodable { let entitlements_token: String }
        var req = URLRequest(url: URL(string: "https://entitlements.auth.riotgames.com/api/token/v1")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{}".utf8)
        let data = try await send(req)
        return try JSONDecoder().decode(R.self, from: data).entitlements_token
    }

    private static func fetchPUUID(access: String) async throws -> String {
        struct R: Decodable { let sub: String }
        var req = URLRequest(url: URL(string: "https://auth.riotgames.com/userinfo")!)
        req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        let data = try await send(req)
        return try JSONDecoder().decode(R.self, from: data).sub
    }

    private static func storefront(access: String, entitlement: String, version: String,
                                   shard: String, puuid: String) async throws -> SkinsPanel {
        let platformJSON = #"{"platformType":"PC","platformOS":"Windows","platformOSVersion":"10.0.19042.1.256.64bit","platformChipset":"Unknown"}"#
        let platform = Data(platformJSON.utf8).base64EncodedString()

        func make(_ path: String, method: String) -> URLRequest {
            var req = URLRequest(url: URL(string: "https://pd.\(shard).a.pvp.net/store/\(path)/storefront/\(puuid)")!)
            req.httpMethod = method
            req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
            req.setValue(entitlement, forHTTPHeaderField: "X-Riot-Entitlements-JWT")
            req.setValue(version, forHTTPHeaderField: "X-Riot-ClientVersion")
            req.setValue(platform, forHTTPHeaderField: "X-Riot-ClientPlatform")
            if method == "POST" {
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = Data("{}".utf8)
            }
            return req
        }

        // Önce v3 (POST), olmazsa v2 (GET) dene
        do {
            let data = try await send(make("v3", method: "POST"))
            return try JSONDecoder().decode(StorefrontResponse.self, from: data).SkinsPanelLayout
        } catch RiotError.unauthorized {
            throw RiotError.unauthorized
        } catch {
            let data = try await send(make("v2", method: "GET"))
            return try JSONDecoder().decode(StorefrontResponse.self, from: data).SkinsPanelLayout
        }
    }

    private static func skinInfo(_ uuid: String) async throws -> SkinLevelResponse.Item {
        let req = URLRequest(url: URL(string: "https://valorant-api.com/v1/weapons/skinlevels/\(uuid)")!)
        let data = try await send(req)
        return try JSONDecoder().decode(SkinLevelResponse.self, from: data).data
    }

    private static func send(_ req: URLRequest) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RiotError.other("Geçersiz yanıt.") }
        if http.statusCode == 401 || http.statusCode == 403 { throw RiotError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw RiotError.http(http.statusCode) }
        return data
    }
}
