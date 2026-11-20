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

struct Chroma: Identifiable {
    let id: String
    let name: String
    let image: URL?
    let swatch: URL?
}
struct Skin: Identifiable {
    let id: String
    let name: String
    let icon: URL?
    let price: Int?
    var oldPrice: Int? = nil
    var discount: Int? = nil
    var weapon: String? = nil
    var chromas: [Chroma] = []
    var levelNames: [String] = []
}
struct Wallet { let vp: Int; let rp: Int; let kc: Int }
struct Profile {
    var name: String
    var level: Int?
    var rank: String
    var rankIcon: URL?
    var rr: Int?
    var cardURL: URL?
    var title: String?
}
struct MatchItem: Identifiable {
    let id: String
    let map: String
    let mapIcon: URL?
    let agent: String
    let agentIcon: URL?
    let queue: String
    let kills: Int
    let deaths: Int
    let assists: Int
    let won: Bool?
    let score: String
    let date: Date
}
struct RankPoint: Identifiable {
    let id: Int
    let rating: Int
    let earned: Int
}
struct StoreResult {
    let skins: [Skin]
    let remaining: Int
    let night: [Skin]
    let nightRemaining: Int?
}
struct Dashboard {
    let skins: [Skin]
    let remaining: Int
    let night: [Skin]
    let nightRemaining: Int?
    let wallet: Wallet?
    let inventory: [Skin]?
    let profile: Profile?
    let matches: [MatchItem]?
    let rankPoints: [RankPoint]?
}
struct Creds {
    let access: String
    let entitlement: String
    let version: String
    let puuid: String
    let shard: String
}

enum RiotAPI {
    static let vpCurrency = "85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741"
    static let rpCurrency = "e59aa87c-4cbf-517a-5983-6e81511be9b7"
    static let kcCurrency = "f08d4ae3-939c-4576-ab26-09ce1f23bb37"
    static let skinLevelType = "e7c63390-eda7-46e0-bb7a-a6abdacd2433"

    static let authorizeURL = URL(string:
        "https://auth.riotgames.com/authorize?redirect_uri=https%3A%2F%2Fplayvalorant.com%2Fopt_in&client_id=play-valorant-web-prod&response_type=token%20id_token&nonce=1&scope=account%20openid"
    )!

    static let platform = Data(#"{"platformType":"PC","platformOS":"Windows","platformOSVersion":"10.0.19042.1.256.64bit","platformChipset":"Unknown"}"#.utf8).base64EncodedString()

    static func vapi(_ path: String) -> URLRequest {
        URLRequest(url: URL(string: "https://valorant-api.com/v1/\(path)")!)
    }

    // MARK: - Oturum

    static func makeCreds(access: String, shard: String) async throws -> Creds {
        struct V: Decodable { struct D: Decodable { let riotClientVersion: String }; let data: D }
        struct Ent: Decodable { let entitlements_token: String }
        struct Info: Decodable { let sub: String }

        let version = try await get(V.self, vapi("version")).data.riotClientVersion

        var e = URLRequest(url: URL(string: "https://entitlements.auth.riotgames.com/api/token/v1")!)
        e.httpMethod = "POST"
        e.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        e.setValue("application/json", forHTTPHeaderField: "Content-Type")
        e.httpBody = Data("{}".utf8)
        let ent = try await get(Ent.self, e).entitlements_token

        var u = URLRequest(url: URL(string: "https://auth.riotgames.com/userinfo")!)
        u.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        let puuid = try await get(Info.self, u).sub

        return Creds(access: access, entitlement: ent, version: version, puuid: puuid, shard: shard)
    }

    static func pd(_ c: Creds, _ path: String, method: String = "GET", body: String? = nil) -> URLRequest {
        var req = URLRequest(url: URL(string: "https://pd.\(c.shard).a.pvp.net/\(path)")!)
        req.httpMethod = method
        req.setValue("Bearer \(c.access)", forHTTPHeaderField: "Authorization")
        req.setValue(c.entitlement, forHTTPHeaderField: "X-Riot-Entitlements-JWT")
        req.setValue(c.version, forHTTPHeaderField: "X-Riot-ClientVersion")
        req.setValue(platform, forHTTPHeaderField: "X-Riot-ClientPlatform")
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data(body.utf8)
        }
        return req
    }

    // MARK: - Skin kataloğu (isim, silah, seviye, renk varyantları)

    struct WeaponsResp: Decodable {
        struct W: Decodable { let displayName: String; let skins: [S] }
        struct S: Decodable {
            struct L: Decodable { let uuid: String; let displayName: String?; let displayIcon: String? }
            struct C: Decodable { let uuid: String; let displayName: String?; let fullRender: String?; let swatch: String? }
            let displayName: String
            let displayIcon: String?
            let levels: [L]?
            let chromas: [C]?
        }
        let data: [W]
    }

    /// Her skin seviyesinin UUID'sinden skin bilgisine giden sözlük.
    static func catalog() async throws -> [String: Skin] {
        let r = try await get(WeaponsResp.self, vapi("weapons"))
        var map: [String: Skin] = [:]
        for w in r.data {
            for s in w.skins {
                guard let levels = s.levels, let first = levels.first else { continue }
                let chromas = (s.chromas ?? []).map {
                    Chroma(id: $0.uuid, name: $0.displayName ?? "",
                           image: $0.fullRender.flatMap { URL(string: $0) },
                           swatch: $0.swatch.flatMap { URL(string: $0) })
                }
                let skin = Skin(id: first.uuid, name: s.displayName,
                                icon: (s.displayIcon ?? first.displayIcon).flatMap { URL(string: $0) },
                                price: nil, weapon: w.displayName, chromas: chromas,
                                levelNames: levels.compactMap { $0.displayName })
                for l in levels { map[l.uuid.lowercased()] = skin }
            }
        }
        return map
    }

    struct SkinLevelResponse: Decodable {
        struct Item: Decodable { let displayName: String; let displayIcon: String? }
        let data: Item
    }

    static func resolve(_ uuid: String, catalog: [String: Skin]?, price: Int?,
                        oldPrice: Int? = nil, discount: Int? = nil) async -> Skin {
        if let c = catalog?[uuid.lowercased()] {
            return Skin(id: uuid, name: c.name, icon: c.icon, price: price, oldPrice: oldPrice,
                        discount: discount, weapon: c.weapon, chromas: c.chromas, levelNames: c.levelNames)
        }
        let info = try? await get(SkinLevelResponse.self, vapi("weapons/skinlevels/\(uuid)")).data
        return Skin(id: uuid, name: info?.displayName ?? uuid,
                    icon: info?.displayIcon.flatMap { URL(string: $0) },
                    price: price, oldPrice: oldPrice, discount: discount)
    }

    // MARK: - Mağaza + Gece Pazarı

    struct StorefrontResponse: Decodable {
        let SkinsPanelLayout: SkinsPanel
        let BonusStore: BonusStoreData?
    }
    struct SkinsPanel: Decodable {
        let SingleItemOffers: [String]
        let SingleItemOffersRemainingDurationInSeconds: Int
        let SingleItemStoreOffers: [StoreOffer]?
    }
    struct StoreOffer: Decodable { let OfferID: String; let Cost: [String: Int] }
    struct BonusStoreData: Decodable {
        let BonusStoreOffers: [BonusOffer]
        let BonusStoreRemainingDurationInSeconds: Int
    }
    struct BonusOffer: Decodable {
        let Offer: StoreOffer
        let DiscountPercent: Int
        let DiscountCosts: [String: Int]
    }

    static func fetchStore(_ c: Creds, catalog: [String: Skin]?) async throws -> StoreResult {
        let resp: StorefrontResponse
        do {
            resp = try await get(StorefrontResponse.self,
                                 pd(c, "store/v3/storefront/\(c.puuid)", method: "POST", body: "{}"))
        } catch RiotError.unauthorized {
            throw RiotError.unauthorized
        } catch {
            resp = try await get(StorefrontResponse.self, pd(c, "store/v2/storefront/\(c.puuid)"))
        }
        let panel = resp.SkinsPanelLayout
        var skins: [Skin] = []
        for uuid in panel.SingleItemOffers {
            let price = panel.SingleItemStoreOffers?.first(where: { $0.OfferID == uuid })?.Cost[vpCurrency]
            skins.append(await resolve(uuid, catalog: catalog, price: price))
        }
        var night: [Skin] = []
        for o in resp.BonusStore?.BonusStoreOffers ?? [] {
            night.append(await resolve(o.Offer.OfferID, catalog: catalog,
                                       price: o.DiscountCosts[vpCurrency],
                                       oldPrice: o.Offer.Cost[vpCurrency],
                                       discount: o.DiscountPercent))
        }
        return StoreResult(skins: skins, remaining: panel.SingleItemOffersRemainingDurationInSeconds,
                           night: night, nightRemaining: resp.BonusStore?.BonusStoreRemainingDurationInSeconds)
    }

    // MARK: - Cüzdan

    static func wallet(_ c: Creds) async throws -> Wallet {
        struct R: Decodable { let Balances: [String: Int] }
        let r = try await get(R.self, pd(c, "store/v1/wallet/\(c.puuid)"))
        return Wallet(vp: r.Balances[vpCurrency] ?? 0, rp: r.Balances[rpCurrency] ?? 0, kc: r.Balances[kcCurrency] ?? 0)
    }

    // MARK: - Envanter

    static func inventory(_ c: Creds, catalog: [String: Skin]) async throws -> [Skin] {
        struct E: Decodable { struct I: Decodable { let ItemID: String }; let Entitlements: [I] }
        let e = try await get(E.self, pd(c, "store/v1/entitlements/\(c.puuid)/\(skinLevelType)"))
        let owned = Set(e.Entitlements.map { $0.ItemID.lowercased() })
        var seen = Set<String>()
        var result: [Skin] = []
        for s in catalog.values {
            let key = s.id.lowercased()
            guard owned.contains(key), !seen.contains(key) else { continue }
            if s.name.hasPrefix("Standard") || s.name.hasPrefix("Random Favorite") { continue }
            seen.insert(key)
            result.append(s)
        }
        return result.sorted { $0.name < $1.name }
    }

    static func inventoryOrNil(_ c: Creds, _ catalog: [String: Skin]?) async -> [Skin]? {
        guard let catalog = catalog else { return nil }
        return try? await inventory(c, catalog: catalog)
    }

    // MARK: - Profil

    struct NameR: Decodable { let GameName: String; let TagLine: String }
    struct XPR: Decodable { struct P: Decodable { let Level: Int }; let Progress: P }
    struct MMR: Decodable {
        struct M: Decodable { let TierAfterUpdate: Int; let RankedRatingAfterUpdate: Int }
        let Matches: [M]
    }
    struct Tiers: Decodable {
        struct Ep: Decodable {
            struct T: Decodable { let tier: Int; let tierName: String; let smallIcon: String? }
            let tiers: [T]
        }
        let data: [Ep]
    }
    struct Loadout: Decodable {
        struct I: Decodable { let PlayerCardID: String; let PlayerTitleID: String }
        let Identity: I
    }
    struct CardR: Decodable { struct D: Decodable { let displayIcon: String?; let wideArt: String? }; let data: D }
    struct TitleR: Decodable { struct D: Decodable { let titleText: String? }; let data: D }

    static func profile(_ c: Creds) async -> Profile {
        var p = Profile(name: "Bilinmiyor", level: nil, rank: "Derecesiz", rankIcon: nil, rr: nil, cardURL: nil, title: nil)

        if let arr = try? await get([NameR].self, pd(c, "name-service/v2/players", method: "PUT", body: "[\"\(c.puuid)\"]")),
           let n = arr.first {
            p.name = "\(n.GameName)#\(n.TagLine)"
        }
        if let xp = try? await get(XPR.self, pd(c, "account-xp/v1/players/\(c.puuid)")) {
            p.level = xp.Progress.Level
        }
        if let mmr = try? await get(MMR.self,
                pd(c, "mmr/v1/players/\(c.puuid)/competitiveupdates?startIndex=0&endIndex=1&queue=competitive")),
           let m = mmr.Matches.first {
            p.rr = m.RankedRatingAfterUpdate
            if let tiers = try? await get(Tiers.self, vapi("competitivetiers")),
               let t = tiers.data.last?.tiers.first(where: { $0.tier == m.TierAfterUpdate }) {
                p.rank = t.tierName.capitalized
                p.rankIcon = t.smallIcon.flatMap { URL(string: $0) }
            }
        }
        if let lo = try? await get(Loadout.self, pd(c, "personalization/v2/players/\(c.puuid)/playerloadout")) {
            if let card = try? await get(CardR.self, vapi("playercards/\(lo.Identity.PlayerCardID)")) {
                p.cardURL = (card.data.wideArt ?? card.data.displayIcon).flatMap { URL(string: $0) }
            }
            if let t = try? await get(TitleR.self, vapi("playertitles/\(lo.Identity.PlayerTitleID)")) {
                p.title = t.data.titleText
            }
        }
        return p
    }

    // MARK: - Rank grafiği

    struct CompUpdates: Decodable {
        struct M: Decodable {
            let TierAfterUpdate: Int
            let RankedRatingAfterUpdate: Int
            let RankedRatingEarned: Int?
        }
        let Matches: [M]
    }

    static func rankHistory(_ c: Creds) async throws -> [RankPoint] {
        let r = try await get(CompUpdates.self,
            pd(c, "mmr/v1/players/\(c.puuid)/competitiveupdates?startIndex=0&endIndex=20&queue=competitive"))
        let oldestFirst = Array(r.Matches.reversed())
        var points: [RankPoint] = []
        for (i, m) in oldestFirst.enumerated() {
            let rating = max(m.TierAfterUpdate - 3, 0) * 100 + m.RankedRatingAfterUpdate
            points.append(RankPoint(id: i, rating: rating, earned: m.RankedRatingEarned ?? 0))
        }
        return points
    }

    // MARK: - Maç geçmişi

    struct HistoryR: Decodable {
        struct H: Decodable { let MatchID: String }
        let History: [H]
    }
    struct MatchDetail: Decodable {
        struct Info: Decodable { let mapId: String; let queueID: String?; let gameStartMillis: Double }
        struct P: Decodable {
            struct St: Decodable { let kills: Int; let deaths: Int; let assists: Int }
            let subject: String
            let teamId: String
            let characterId: String?
            let stats: St?
        }
        struct T: Decodable { let teamId: String; let won: Bool; let roundsWon: Int? }
        let matchInfo: Info
        let players: [P]
        let teams: [T]?
    }
    struct MapsR: Decodable {
        struct M: Decodable { let mapUrl: String?; let displayName: String; let listViewIcon: String? }
        let data: [M]
    }
    struct AgentsR: Decodable {
        struct A: Decodable { let uuid: String; let displayName: String; let displayIcon: String? }
        let data: [A]
    }

    static func queueName(_ q: String?) -> String {
        switch q ?? "" {
        case "competitive": return "Rekabetçi"
        case "unrated": return "Derecesiz"
        case "spikerush": return "Spike Rush"
        case "deathmatch": return "Deathmatch"
        case "swiftplay": return "Hızlı Oyun"
        case "premier": return "Premier"
        case "": return "Özel"
        default: return (q ?? "").capitalized
        }
    }

    static func matches(_ c: Creds) async throws -> [MatchItem] {
        let hist = try await get(HistoryR.self,
            pd(c, "match-history/v1/history/\(c.puuid)?startIndex=0&endIndex=10"))
        let maps = (try? await get(MapsR.self, vapi("maps")))?.data ?? []
        let agents = (try? await get(AgentsR.self, vapi("agents?isPlayableCharacter=true")))?.data ?? []

        var found: [(Int, MatchItem)] = []
        await withTaskGroup(of: (Int, MatchItem?).self) { group in
            for (i, h) in hist.History.enumerated() {
                group.addTask {
                    guard let d = try? await RiotAPI.get(MatchDetail.self,
                            RiotAPI.pd(c, "match-details/v1/matches/\(h.MatchID)")),
                          let me = d.players.first(where: { $0.subject == c.puuid }) else {
                        return (i, nil)
                    }
                    let map = maps.first(where: { $0.mapUrl == d.matchInfo.mapId })
                    let agent = agents.first(where: { $0.uuid.lowercased() == (me.characterId ?? "").lowercased() })
                    let mine = d.teams?.first(where: { $0.teamId == me.teamId })
                    let other = d.teams?.first(where: { $0.teamId != me.teamId })
                    var score = "-"
                    if let a = mine?.roundsWon, let b = other?.roundsWon { score = "\(a)-\(b)" }
                    let item = MatchItem(
                        id: h.MatchID,
                        map: map?.displayName ?? "Bilinmeyen harita",
                        mapIcon: map?.listViewIcon.flatMap { URL(string: $0) },
                        agent: agent?.displayName ?? "-",
                        agentIcon: agent?.displayIcon.flatMap { URL(string: $0) },
                        queue: RiotAPI.queueName(d.matchInfo.queueID),
                        kills: me.stats?.kills ?? 0,
                        deaths: me.stats?.deaths ?? 0,
                        assists: me.stats?.assists ?? 0,
                        won: mine?.won,
                        score: score,
                        date: Date(timeIntervalSince1970: d.matchInfo.gameStartMillis / 1000)
                    )
                    return (i, item)
                }
            }
            for await (i, item) in group {
                if let item = item { found.append((i, item)) }
            }
        }
        return found.sorted { $0.0 < $1.0 }.map { $0.1 }
    }

    // MARK: - HTTP

    static func get<T: Decodable>(_ type: T.Type, _ req: URLRequest) async throws -> T {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RiotError.other("Geçersiz yanıt.") }
        if http.statusCode == 401 || http.statusCode == 403 { throw RiotError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw RiotError.http(http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
