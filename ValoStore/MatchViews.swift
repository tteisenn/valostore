import SwiftUI
import Charts

struct MatchesTab: View {
    let matches: [MatchItem]?
    let points: [RankPoint]?
    let vm: StoreViewModel

    var body: some View {
        NavigationStack {
            List {
                if let pts = points, pts.count > 1 {
                    let lo = (pts.map { $0.rating }.min() ?? 0) - 20
                    let hi = (pts.map { $0.rating }.max() ?? 0) + 20
                    Section("Rank grafiği (son \(pts.count) rekabetçi maç)") {
                        Chart(pts) { p in
                            LineMark(x: .value("Maç", p.id), y: .value("Puan", p.rating))
                            PointMark(x: .value("Maç", p.id), y: .value("Puan", p.rating))
                        }
                        .chartYScale(domain: lo...hi)
                        .frame(height: 200)
                        Text("Her 100 puan bir kademe (örn. Gold 1 → Gold 2).")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(Array(pts.reversed().prefix(10))) { p in
                            HStack {
                                Text("Maç \(p.id + 1)")
                                Spacer()
                                Text(p.earned >= 0 ? "+\(p.earned) RR" : "\(p.earned) RR")
                                    .bold()
                                    .foregroundStyle(p.earned >= 0 ? Color.green : Color.red)
                            }
                        }
                    }
                } else if points != nil {
                    Section("Rank grafiği") { Text("Rekabetçi maç verisi bulunamadı.") }
                }

                Section("Son maçlar") {
                    if let ms = matches {
                        if ms.isEmpty {
                            Text("Maç bulunamadı.")
                        } else {
                            ForEach(ms) { MatchRow(m: $0) }
                        }
                    } else {
                        Text("Maç geçmişi yüklenemedi.")
                    }
                }
            }
            .refreshable { await vm.refresh() }
            .navigationTitle("Maçlar")
            .appMenu(vm)
        }
    }
}

struct MatchRow: View {
    let m: MatchItem
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: m.agentIcon) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.15)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(m.map) · \(m.queue)").font(.headline)
                Text("\(m.agent) · \(m.kills)/\(m.deaths)/\(m.assists)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(m.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let won = m.won {
                    Text(won ? "Galibiyet" : "Mağlubiyet")
                        .bold()
                        .foregroundStyle(won ? Color.green : Color.red)
                }
                Text(m.score).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
