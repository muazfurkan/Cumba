<p align="center"><img src="docs/icon.png" width="128" alt="ljaspNotch simgesi"></p>

# ljaspNotch

[English](README.md)

macOS için özelleştirilebilir bir notch uygulaması. MacBook notch'unu, üzerine gelince genişleyen bir panele çevirir.

> **Durum: geliştiriliyor.** Henüz indirilebilir bir sürüm yok. Yol haritası ve teknik spesifikasyon [docs/SPEC.md](docs/SPEC.md) dosyasında.

## Planlanan özellikler

- Tarayıcıda çalan müzik ve videolar için **YouTube ve YouTube Music** mini oynatıcısı (Chrome eklentisi)
- Kapak görseli ve ilerleme çubuğuyla **Spotify ve Apple Music** kontrolleri
- **Claude Code** bildirimleri; izin isteklerini doğrudan notch'tan onaylama veya reddetme
- **Temalar**: Liquid Glass, düz siyah veya renkli cam; özel renkler, panel boyutu ve animasyonlar
- **Widget'lar**: takvim, zamanlayıcı, batarya, dosya rafı, kamera aynası, hava durumu, kısayollar ve daha fazlası
- Türkçe ve İngilizce arayüz

## Gereksinimler

- Notch'lu bir Mac
- macOS 26 veya üstü

## Kaynaktan derleme

Xcode 26 veya üstü ve [Homebrew](https://brew.sh) gerekir.

```bash
brew install xcodegen
git clone https://github.com/muazfurkan/ljaspNotch.git
cd ljaspNotch
cp Local.xcconfig.example Local.xcconfig   # ardından DEVELOPMENT_TEAM değerini gir
xcodegen generate
open ljaspNotch.xcodeproj
```

Ayrıntılar için [CONTRIBUTING.md](CONTRIBUTING.md) dosyasına bakın.

## YouTube ve YouTube Music

Küçük bir Chrome eklentisi (diğer Chromium tarayıcılarda da çalışır) YouTube sekmelerinde çalanı yerel bir bağlantı üzerinden uygulamaya gönderir; uygulama da oynat, duraklat, sonraki ve sarma komutlarını geri yollar.

1. ljaspNotch'ta **Ayarlar > Bağlantılar**'ı açın ve **Eklenti Klasörünü Göster**'e tıklayın.
2. Chrome'da `chrome://extensions` adresini açın, **Geliştirici modu**'nu etkinleştirin ve **Paketlenmemiş öğe yükle**'ye tıklayın. 1. adımdaki klasörü seçin.
3. Eklentinin **Ayrıntılar > Eklenti seçenekleri** sayfasını açın, **Ayarlar > Bağlantılar**'daki portu ve token'ı yapıştırıp kaydedin.

Eklentinin depolama dışında izni yoktur, yalnızca `youtube.com` ve `music.youtube.com` sayfalarını okur ve yalnızca `127.0.0.1` ile konuşur.

## Claude Code

Claude Code'un (terminal, IDE eklentileri ve Claude masaüstü uygulaması) izin istekleri **İzin Ver**, **Reddet** ve **Terminalde** seçenekleriyle notch'ta görünür; bir oturum bitince veya hata verince de görürsünüz. Hook'ları **Ayarlar > Claude Code**'dan kurun; `~/.claude/settings.json` değişikliğini önce siz görürsünüz ve yedek alınır. Elle kurulum için [docs/claude-code-setup.md](docs/claude-code-setup.md) dosyasına bakın.

## Gizlilik

Telemetri yok. Her şey Mac'inizde kalır. Şu özellikler ağ isteği yapar, yalnızca siz kullanırken:

| Özellik | İstek |
|---|---|
| Spotify ile medya widget'ı | Spotify'ın görsel sunucusundan (`i.scdn.co`) kapak görseli |
| YouTube ile medya widget'ı | YouTube'un görsel sunucularından küçük resim (sayfanın kendi kullandığı adres) |

Yerel sunucu yalnızca `127.0.0.1` adresini dinler ve Anahtar Zinciri'nde saklanan bir token ister. Ad-hoc imzalı bir sürümü güncelledikten sonra macOS bir kez daha Anahtar Zinciri erişimi sorabilir.

## Katkı

Katkılara açığız. Lütfen [CONTRIBUTING.md](CONTRIBUTING.md) ve [Davranış Kuralları](CODE_OF_CONDUCT.md) belgelerini okuyun. Güvenlik açıklarını [SECURITY.md](SECURITY.md) dosyasında anlatıldığı gibi gizli olarak bildirin.

## Lisans

[MIT](LICENSE)
