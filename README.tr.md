<p align="center"><img src="docs/banner.png" alt="Notch'un altında açılmış ljaspNotch paneli ve mini oynatıcı"></p>

<h1 align="center">ljaspNotch</h1>

<p align="center">
  <a href="https://github.com/muazfurkan/ljaspNotch/releases/latest"><img src="https://img.shields.io/github/v/release/muazfurkan/ljaspNotch?label=download&color=DCB669" alt="Son sürüm"></a>
  <a href="https://github.com/muazfurkan/ljaspNotch/actions/workflows/build.yml"><img src="https://github.com/muazfurkan/ljaspNotch/actions/workflows/build.yml/badge.svg?branch=main" alt="Derleme durumu"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-111111?logo=apple" alt="macOS 26 veya üstü">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/muazfurkan/ljaspNotch?color=111111" alt="MIT lisansı"></a>
</p>

<p align="center"><a href="README.md">English</a></p>

macOS için ücretsiz ve açık kaynak bir notch uygulaması. MacBook notch'unu, imleci üzerinde tuttuğunuzda kamera yuvasından büyüyen bir panele çevirir: Spotify, Apple Music ve YouTube'dan müzik, Claude Code izin istekleri ve bir dizi widget; hepsi size göre ayarlanabilen bir görünümle.

## Özellikler

- **Medya**: Spotify, Apple Music, YouTube ve YouTube Music tek bir mini oynatıcıda; kapak görseli, ilerleme, sarma ve kontroller. Notch'un yanındaki küçük ses dalgası neyin çaldığını gösterir.
- **Claude Code**: terminaldeki, IDE eklentilerindeki veya Claude masaüstü uygulamasındaki izin istekleri **İzin Ver**, **Reddet** ve **Terminalde** seçenekleriyle notch'ta görünür. Bir oturum bitince veya hata verince de görürsünüz.
- **Sekmelerde widget'lar**: takvim, zamanlayıcı, pil, AirDrop destekli dosya rafı, kamera aynası, hava durumu, Kısayollar ve CPU/bellek grafiği. Ayarlar'dan ekleyin, kaldırın, sıralayın.
- **Canlı etkinlikler**: çalışan zamanlayıcı, bekleyen Claude isteği, şarj veya çalan şarkı kapalı notch'un iki yanında görünür.
- **Temalar**: Liquid Glass, düz siyah veya renkli cam; renkler, yazı tipi, panel boyutu, köşe yuvarlaklığı, gölge ve animasyon. Temaları JSON olarak içe/dışa aktarın.
- **Yolunuza çıkmaz**: tıklamalar menü çubuğuna geçer, panel tam ekran uygulamalarda gizlenir, boşta CPU kullanımı sıfırdır.
- Türkçe ve İngilizce arayüz.

## İndirme

1. [Releases](https://github.com/muazfurkan/ljaspNotch/releases) sayfasından `ljaspNotch-vX.Y.Z.zip` dosyasını indirin ve `ljaspNotch.app`'i Uygulamalar klasörüne taşıyın.
2. Uygulama ücretsizdir ve Apple tarafından notarize edilmemiştir, bu yüzden macOS ilk açılışta uyarır. Bir kez açmayı deneyin, ardından **Sistem Ayarları > Gizlilik ve Güvenlik**'te **Yine de Aç**'a tıklayın. Ya da şunu çalıştırın:
   ```bash
   xattr -dr com.apple.quarantine /Applications/ljaspNotch.app
   ```
3. ljaspNotch menü çubuğunda yaşar. Menü çubuğu kalabalıksa ve simgesi notch'un arkasında kalırsa, Ayarlar'a ulaşmak için uygulamayı Finder'dan veya Spotlight'tan yeniden açın.

Her sürümde dosyaların yanında SHA-256 değerleri vardır. 1.0.0'dan sonraki sürümler ayrıca değiştirilemezdir (yayımlandıktan sonra dosyaları ve etiketi değişemez) ve imzalı derleme kaynağı (build provenance) taşır; indirdiğiniz dosyanın bu reponun yayın iş akışında derlendiğini şöyle doğrulayabilirsiniz:

```bash
gh attestation verify ljaspNotch-vX.Y.Z.zip --repo muazfurkan/ljaspNotch
```

Sürümler ad-hoc imzalı olduğu için güncellemeden sonra macOS izinleri (Otomasyon, Takvim, Kamera) ve Anahtar Zinciri erişimini yeniden sorabilir.

## Gereksinimler

- Notch'lu bir Mac (diğer Mac'ler sanal notch gösterebilir, bkz. Ayarlar > Genel)
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

Claude Code'un (terminal, IDE eklentileri ve Claude masaüstü uygulaması) izin istekleri **İzin Ver**, **Reddet** ve **Terminalde** seçenekleriyle notch'ta görünür; bir oturum bitince veya hata verince de görürsünüz. Kart, isteğin tamamını gizli karakterleri görünür hale getirerek gösterir. Hook'ları **Ayarlar > Claude Code**'dan kurun; `~/.claude/settings.json` değişikliğini önce siz görürsünüz ve yedek alınır. Hook'lar uygulamaya yalnızca sizin kullanıcı hesabınızın açabildiği özel bir soket üzerinden ulaşır; böylece başka hiçbir şey Claude Code'a uygulama adına cevap veremez. Ayrıntılar ve elle kurulum için [docs/claude-code-setup.md](docs/claude-code-setup.md) dosyasına bakın.

## Gizlilik

Telemetri yok. Her şey Mac'inizde kalır. Şu özellikler ağ isteği yapar, yalnızca siz kullanırken:

| Özellik | İstek |
|---|---|
| Spotify ile medya widget'ı | Spotify'ın görsel sunucusundan (`i.scdn.co`) kapak görseli |
| YouTube ile medya widget'ı | YouTube'un görsel sunucularından küçük resim (sayfanın kendi kullandığı adres) |
| Hava durumu widget'ı | Seçtiğiniz konumun koordinatları `api.open-meteo.com`'a; aradığınız şehir adı `geocoding-api.open-meteo.com`'a |
| Güncelleme denetimi | Açılışta ve günde bir kez `api.github.com`'dan sürüm listesi; Ayarlar > Genel'den kapatılabilir |

Kamera (Ayna widget'ı) yalnızca panel onu gösterirken çalışır ve hiçbir şey kaydedilmez. Raf yalnızca dosya yollarını Mac'inizde tutar.

Eklenti sunucusu yalnızca `127.0.0.1` adresini dinler, yalnızca ljaspNotch eklentisini kabul eder ve Anahtar Zinciri'nde saklanan bir token ister. Ad-hoc imzalı bir sürümü güncelledikten sonra macOS bir kez daha Anahtar Zinciri erişimi sorabilir.

## Katkı

Sorular ve fikirler için [Discussions](https://github.com/muazfurkan/ljaspNotch/discussions) bölümünü kullanabilirsiniz. Katkılara da açığız; lütfen [CONTRIBUTING.md](CONTRIBUTING.md) ve [Davranış Kuralları](CODE_OF_CONDUCT.md) belgelerini okuyun. Güvenlik açıklarını [SECURITY.md](SECURITY.md) dosyasında anlatıldığı gibi gizli olarak bildirin.

## Lisans

[MIT](LICENSE)
