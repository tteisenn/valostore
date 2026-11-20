# Valo Mağaza — Kurulum (Mac'siz)

## 1) GitHub'a yükle
1. github.com'da ücretsiz hesap aç, yeni bir repo oluştur (adı: valostore). Public veya private olur.
2. "Add file > Upload files" ile bu klasörün İÇİNDEKİ her şeyi sürükle-bırak:
   `project.yml`, `ValoStore/` klasörü, `.github/` klasörü, `.gitignore`.
   (`.github` yüklenmezse: "Add file > Create new file", adı `.github/workflows/build.yml`
   yaz ve build.yml içeriğini yapıştır.)
3. "Commit changes" de.

## 2) IPA'yı derlet
1. Repoda **Actions** sekmesi > **Build IPA** > **Run workflow**.
2. ~5-10 dk sonra yeşil tik çıkınca run'a gir, en alttaki **ValoStore-ipa** dosyasını indir.
3. İndirdiğin zip'i aç, içinden `ValoStore.ipa` çıkar.

## 3) Telefona yükle (Windows)
1. sideloadly.io'dan Sideloadly'yi kur. iTunes ve iCloud'u Apple'ın sitesinden indirilen sürümle kur (Microsoft Store sürümü değil).
2. iPhone'u USB ile bağla, "Bu bilgisayara güven" de.
3. Sideloadly'de `ValoStore.ipa`'yı sürükle, Apple ID'ni yaz, **Start**.
4. iPhone: Ayarlar > Gizlilik ve Güvenlik > **Geliştirici Modu** aç (telefon yeniden başlar).
5. Ayarlar > Genel > VPN ve Cihaz Yönetimi > Apple ID'ne dokun > **Güven**.
6. Uygulamayı aç, Riot hesabınla giriş yap.

## Notlar
- Ücretsiz Apple ID ile uygulama 7 günde bir süresi dolar: Sideloadly ile aynı IPA'yı tekrar yükle.
- Token 1 saat geçerli. Süre dolunca giriş sayfası açılır, Riot oturumu hatırlıyorsa otomatik geçer.
- Bölge: sağ üstteki menüden seç (Türkiye için EU).
