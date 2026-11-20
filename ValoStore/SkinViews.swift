import SwiftUI

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
                if let w = skin.weapon {
                    Text(w).font(.caption).foregroundStyle(.secondary)
                }
                if let price = skin.price {
                    if let old = skin.oldPrice, let d = skin.discount {
                        HStack(spacing: 6) {
                            Text("\(old)").strikethrough().foregroundStyle(.secondary)
                            Text("\(price) VP").bold()
                            Text("-%\(d)").font(.caption).foregroundStyle(.green)
                        }
                    } else {
                        Text("\(price) VP").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SkinDetail: View {
    let skin: Skin
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AsyncImage(url: skin.icon) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: 180)

                if let w = skin.weapon {
                    Text(w).foregroundStyle(.secondary)
                }
                if let price = skin.price {
                    if let old = skin.oldPrice, let d = skin.discount {
                        Text("\(old) → \(price) VP (-%\(d))").font(.headline)
                    } else {
                        Text("\(price) VP").font(.headline)
                    }
                }

                if !skin.levelNames.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Seviyeler").font(.headline)
                        ForEach(Array(skin.levelNames.enumerated()), id: \.offset) { item in
                            Text("\(item.offset + 1). \(item.element)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !skin.chromas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Renk varyantları").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                            ForEach(skin.chromas) { ch in
                                VStack {
                                    AsyncImage(url: ch.image ?? ch.swatch) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: {
                                        Color.gray.opacity(0.15)
                                    }
                                    .frame(height: 70)
                                    Text(ch.name)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle(skin.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
