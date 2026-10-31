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

> **Proje durumu:** ljaspNotch yeni (ilk sürüm Ekim 2026) ve tek bir geliştirici tarafından yapay zeka desteğiyle (Claude Code) geliştiriliyor. Bağımsız bir güvenlik denetiminden geçmedi. Kod küçük ve açık, sürümler etiketli commit'lerden GitHub Actions'ta derleniyor; [nelere erişebildiği](#izinler) ve [indirilen dosyanın nasıl doğrulanacağı](#indirme) aşağıda.

## Özellikler

- **Medya**: Spotify, Apple Music, YouTube ve YouTube Music tek bir mini oynatıcıda; kapak görseli, ilerleme, sarma ve kontroller. Notch'un yanındaki küçük ses dalgası neyin çaldığını gösterir.
- **Claude Code**: terminaldeki, IDE eklentilerindeki veya Claude masaüstü uygulamasındaki izin istekleri **İzin Ver**, **Reddet** ve **Terminalde** seçenekleriyle notch'ta görünür. Bir oturum bitince veya hata verince de görürsünüz.
- **Sekmelerde widget'lar**: takvim, zamanlayıcı, pil, AirDrop destekli dosya rafı, kamera aynası, hava durumu, Kısayollar ve CPU/bellek grafiği. Ayarlar'daki galeriden seçin, sürükleyerek sıralayın; yeni kurulum yalnızca üçüyle başlar.
- **Canlı etkinlikler**: çalışan zamanlayıcı, bekleyen Claude isteği, şarj veya çalan şarkı kapalı notch'un iki yanında görünür.
- **Temalar**: Liquid Glass, düz siyah veya renkli cam; renkler, yazı tipi, panel boyutu, köşe yuvarlaklığı, gölge ve animasyon. Temaları JSON olarak içe/dışa aktarın.
- **Yolunuza çıkmaz**: tıklamalar menü çubuğuna geçer, pencere sürüklerken panel açılmaz, tam ekran uygulamalarda gizlenir ve boşta CPU kullanımı sıfırdır. Ayarlar için notch'a sağ tıklayın.
- Türkçe ve İngilizce arayüz.

<a name="indirme"></a>

## İndirme ve kurulum

1. [Son sürümden](https://github.com/muazfurkan/ljaspNotch/releases/latest) `ljaspNotch-vX.Y.Z.dmg` (ya da `.zip`) dosyasını indirin.
2. **Açmadan önce dosyayı doğrulayın.** SHA-256 değeri, sürüm sayfasındaki `SHA256SUMS.txt` ile aynı olmalı:
   ```bash
   shasum -a 256 ~/Downloads/ljaspNotch-vX.Y.Z.dmg
   ```
   1.1.0'dan itibaren sürümler ayrıca değiştirilemezdir (yayımlandıktan sonra dosyaları ve etiketi değişemez) ve imzalı derleme kaynağı (build provenance) taşır. [GitHub CLI](https://cli.github.com) ile dosyanın bu reponun yayın iş akışında derlendiğini doğrulayabilirsiniz:
   ```bash
   gh attestation verify ~/Downloads/ljaspNotch-vX.Y.Z.dmg --repo muazfurkan/ljaspNotch
   ```
3. Disk görüntüsünü açın ve ljaspNotch'u Uygulamalar klasörüne sürükleyin.
4. ljaspNotch Apple tarafından notarize edilmedi, çünkü bu ücretli bir geliştirici hesabı gerektiriyor; bu yüzden macOS ilk açılışı engeller. Bir kez açmayı deneyin, ardından **Sistem Ayarları > Gizlilik ve Güvenlik**'te **Yine de Aç**'a tıklayın. İndirilmiş bir derlemeyi hiç çalıştırmak istemezseniz [kaynaktan derleyin](#kaynaktan-derleme).
5. Kısa bir karşılama penceresi paneli denemenizi sağlar. ljaspNotch menü çubuğunda yaşar; simgesi notch'un arkasında kalırsa Ayarlar için notch'a sağ tıklayın.

<details>
<summary>Yine de Aç yerine Terminal</summary>

`xattr -dr com.apple.quarantine /Applications/ljaspNotch.app` yalnızca bu uygulamadaki indirme işaretini kaldırır, Gatekeeper da sormayı bırakır. Bunu yalnızca 2. adımda doğruladığınız bir kopya için yapın.
</details>

**Güncellemeler:** Uygulama yeni sürüm çıktığında haber verir; kendi başına hiçbir şey indirmez veya kurmaz. Sürümler ad-hoc imzalı olduğu için güncellemeden sonra macOS verdiğiniz izinleri (Otomasyon, Takvim, Kamera) ve ljaspNotch'un token'ları için Anahtar Zinciri erişimini yeniden sorar. Önce yeni dosyayı doğrulayın, sonra izin verin.

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

<a name="izinler"></a>

## İzinler ve neler çalışır

Aşağıdakilerin hepsi, gerektiren özelliği açana kadar kapalıdır veya kullanılmaz. Her birinin güncel durumu Ayarlar > İzinler'de görünür.

| Ne | Neden | Ne zaman |
|---|---|---|
| Spotify ve Müzik için Otomasyon (Apple Events) | Çalan parçayı okumak; oynat, duraklat, atla, sar | Ayarlar'dan istenir; komutlar yalnızca o uygulama zaten açıkken gönderilir |
| Takvim (tam erişim) | Takvim widget'ı | Widget'ı kullandığınızda Ayarlar'dan istenir |
| Kamera | Ayna widget'ı | Yalnızca panel onu gösterirken; hiçbir şey kaydedilmez |
| `127.0.0.1` üzerinde yerel sunucu | YouTube eklentisi bağlantısı | Yalnızca Ayarlar > Bağlantılar'dan açtıktan sonra |
| Özel Unix soketi | Claude Code hook'ları | Yalnızca hook'lar kuruluyken |
| `~/.claude/settings.json` | Hook'ları kurmak ve kaldırmak | Yalnızca değişikliği gözden geçirdikten sonra; yedek alınır |
| Giriş öğesi | Oturum açıldığında başlatma | Siz açana kadar kapalı |
| Ağ | Kapak görselleri, hava durumu, güncelleme kontrolü | Bkz. [Gizlilik](#gizlilik) |

App Sandbox kapalı: sandbox'taki bir uygulama Spotify ve Müzik'i komutla yönetmek, Claude Code hook'larının ulaştığı soketi çalıştırmak ve `~/.claude/settings.json` dosyasını düzenlemek için istisnalara ihtiyaç duyar. Hardened Runtime açık ve uygulamanın yalnızca [ljaspNotch.entitlements](ljaspNotch/Resources/ljaspNotch.entitlements) dosyasındaki yetkileri var (Apple Events, takvim, kamera).

ljaspNotch hiçbir zaman telemetri göndermez, Apple'ın özel API'lerini kullanmaz, yönetici parolası istemez, yardımcı araç, çekirdek veya sistem uzantısı kurmaz, sistem ayarlarını değiştirmez, kod indirmez ve kendini güncellemez. Tehdit modeli ve güvenlikle ilgili kodun haritası [SECURITY.md](SECURITY.md) dosyasında.

## YouTube ve YouTube Music

Küçük bir Chrome eklentisi (diğer Chromium tarayıcılarda da çalışır) YouTube sekmelerinde çalanı yerel bir bağlantı üzerinden uygulamaya gönderir; uygulama da oynat, duraklat, sonraki ve sarma komutlarını geri yollar.

1. ljaspNotch'ta **Ayarlar > Bağlantılar**'ı açın, **YouTube eklentisini bağla**'yı açın ve **Eklenti Klasörünü Göster**'e tıklayın.
2. Chrome'da `chrome://extensions` adresini açın, **Geliştirici modu**'nu etkinleştirin ve **Paketlenmemiş öğe yükle**'ye tıklayın. 1. adımdaki klasörü seçin.
3. Eklentinin **Ayrıntılar > Eklenti seçenekleri** sayfasını açın, **Ayarlar > Bağlantılar**'daki portu ve token'ı yapıştırıp kaydedin.

Chrome, eklentinin `youtube.com` ve `music.youtube.com` üzerindeki verilerinizi okuyup değiştirebileceğini söyler: eklenti oynatıcıyı okur (başlık, kapak, ilerleme) ve orada oynat, duraklat, sonraki ve sarma düğmelerine basar. Başka hiçbir sitede çalışmaz, tek diğer izni depolamadır (port ve token için) ve yalnızca `127.0.0.1` ile konuşur.

## Claude Code

Claude Code'un (terminal, IDE eklentileri ve Claude masaüstü uygulaması) izin istekleri **İzin Ver**, **Reddet** ve **Terminalde** seçenekleriyle notch'ta görünür; bir oturum bitince veya hata verince de görürsünüz. Kart, isteğin tamamını gizli karakterleri görünür hale getirerek gösterir. Hook'ları **Ayarlar > Claude Code**'dan kurun; `~/.claude/settings.json` değişikliğini önce siz görürsünüz ve yedek alınır. Hook'lar uygulamaya yalnızca sizin kullanıcı hesabınızın açabildiği özel bir soket üzerinden ulaşır; böylece başka hiçbir şey Claude Code'a uygulama adına cevap veremez; hook'lar eklentininkinden ayrı, kendi token'larını kullanır.

**Notch'taki İzin Ver, Claude Code'daki İzin Ver ile aynıdır: araç hemen çalışır.** Ayarlar > Claude Code'dan notch'ta kabuk komutları dışındaki her şeye izin verilmesini seçebilir ya da İzin Ver'i tamamen kapatıp yalnızca Reddet ve Terminalde seçeneklerini bırakabilirsiniz. Gizli karakter içeren isteklerde İzin Ver düğmesi hiç gösterilmez. Ayrıntılar ve elle kurulum için [docs/claude-code-setup.md](docs/claude-code-setup.md) dosyasına bakın.

## Gizlilik

Telemetri yok. Her şey Mac'inizde kalır. Şu özellikler ağ isteği yapar, yalnızca siz kullanırken:

| Özellik | İstek |
|---|---|
| Spotify ile medya widget'ı | Spotify'ın görsel sunucusundan (`i.scdn.co`) kapak görseli |
| YouTube ile medya widget'ı | YouTube'un görsel sunucularından küçük resim (sayfanın kendi kullandığı adres) |
| Hava durumu widget'ı | Seçtiğiniz konumun koordinatları `api.open-meteo.com`'a; aradığınız şehir adı `geocoding-api.open-meteo.com`'a |
| Güncelleme denetimi | Açılışta ve günde bir kez `api.github.com`'dan sürüm listesi; Ayarlar > Genel'den kapatılabilir |

Kamera (Ayna widget'ı) yalnızca panel onu gösterirken çalışır ve hiçbir şey kaydedilmez. Raf yalnızca dosya yollarını Mac'inizde tutar.

Açıldığında eklenti sunucusu yalnızca `127.0.0.1` adresini dinler, yalnızca ljaspNotch eklentisini kabul eder ve Anahtar Zinciri'nde saklanan kendi token'ını ister.

## Kaldırma

1. Claude Code hook'larını kurduysanız önce **Ayarlar > Claude Code > Kaldır…** ile kaldırın. Uygulama silindikten sonra kalan hook'lar hiçbir şey yapmaz ama `~/.claude/settings.json` içinde kalır.
2. Ayarlar > Genel'de **Oturum açıldığında başlat**'ı kapatın, menü çubuğundan ljaspNotch'tan çıkın ve uygulamayı Çöp Sepeti'ne taşıyın.
3. Eklentiyi `chrome://extensions` sayfasından kaldırın.
4. Verilerini de silmek için (temalar, düzen, tercihler ve token'lar):
   ```bash
   rm -rf ~/Library/Application\ Support/ljaspNotch
   defaults delete io.github.muazfurkan.ljaspnotch
   security delete-generic-password -s io.github.muazfurkan.ljaspnotch.server -a token
   security delete-generic-password -s io.github.muazfurkan.ljaspnotch.server -a extension-token
   ```
   Hook kurulumunda alınan Claude Code ayar yedekleri `~/.claude/settings.json.bak-…` adıyla yanında durur; saklayabilir ya da silebilirsiniz.

## Katkı

Sorular ve fikirler için [Discussions](https://github.com/muazfurkan/ljaspNotch/discussions) bölümünü kullanabilirsiniz. Katkılara da açığız; lütfen [CONTRIBUTING.md](CONTRIBUTING.md) ve [Davranış Kuralları](CODE_OF_CONDUCT.md) belgelerini okuyun. Güvenlik açıklarını [SECURITY.md](SECURITY.md) dosyasında anlatıldığı gibi gizli olarak bildirin.

## Lisans

[MIT](LICENSE)
