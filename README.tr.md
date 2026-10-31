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

## Gizlilik

Telemetri yok. Her şey Mac'inizde kalır. Ağ isteği yapan özellikler burada listelenecek.

## Katkı

Katkılara açığız. Lütfen [CONTRIBUTING.md](CONTRIBUTING.md) ve [Davranış Kuralları](CODE_OF_CONDUCT.md) belgelerini okuyun. Güvenlik açıklarını [SECURITY.md](SECURITY.md) dosyasında anlatıldığı gibi gizli olarak bildirin.

## Lisans

[MIT](LICENSE)
