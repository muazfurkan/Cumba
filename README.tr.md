<p align="center"><img src="docs/banner.png" alt="Notch'un altında açılmış Cumba paneli ve mini oynatıcı"></p>

<h1 align="center">Cumba</h1>

<p align="center"><sub>by LJASP · eski adıyla ljaspNotch</sub></p>

<p align="center">
  <a href="https://github.com/muazfurkan/Cumba/releases/latest"><img src="https://img.shields.io/github/v/release/muazfurkan/Cumba?label=download&color=DCB669" alt="Son sürüm"></a>
  <a href="https://github.com/muazfurkan/Cumba/actions/workflows/build.yml"><img src="https://github.com/muazfurkan/Cumba/actions/workflows/build.yml/badge.svg?branch=main" alt="Derleme durumu"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-111111?logo=apple" alt="macOS 26 veya üstü">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/muazfurkan/Cumba?color=111111" alt="MIT lisansı"></a>
</p>

<p align="center"><a href="README.md">English</a></p>

macOS için ücretsiz ve açık kaynak bir notch uygulaması. MacBook notch'unu, imleci üzerinde tuttuğunuzda kamera yuvasından büyüyen bir panele çevirir: her uygulamadan müzik ve video, Claude Code izin istekleri ve bir dizi widget; hepsi size göre ayarlanabilen bir görünümle.

*Cumba*, eski Türk evlerinin üst katından sokağa taşan küçük çıkmadır: oturup sokakta olup biteni izlediğiniz sakin bir köşe. Panel de aynısını ekranınızın tepesinden yapar.

> **Proje durumu:** Cumba yeni (ilk sürüm Ekim 2026) ve tek bir geliştirici tarafından yapay zeka desteğiyle (Claude Code) geliştiriliyor. Bağımsız bir güvenlik denetiminden geçmedi. Kod küçük ve açık, sürümler etiketli commit'lerden GitHub Actions'ta derleniyor; [nelere erişebildiği](#izinler) ve [indirilen dosyanın nasıl doğrulanacağı](#indirme) aşağıda.

## Özellikler

- **Medya**: hangi uygulama ne çalıyorsa (Safari, Chrome, YouTube, Spotify, Müzik, podcast'ler ve daha fazlası) tek bir mini oynatıcıda; kapak görseli, ilerleme, sarma ve kontroller, eklenti ya da kurulum gerekmeden. Notch'un yanındaki küçük ses dalgası neyin çaldığını gösterir.
- **Yapay zeka ajanları (Claude Code ve Codex)**: ajanın o an ne yaptığı, son yanıtı ve bağlam penceresinin ne kadar dolu olduğu; çalışırken notch'un yanında dönen bir halka, bitince altında bir satır. İzin istekleri **İzin Ver**, **Reddet** ve **Terminalde** seçenekleriyle görünür.
- **Sekmelerde widget'lar**: görüntülü görüşmeler için Katıl düğmeli takvim, zamanlayıcı, Pomodoro, notlar, pano geçmişi, uyanık tut, teleprompter, pil, AirDrop destekli dosya rafı, kamera aynası, hava durumu, Kısayollar ve CPU/bellek grafiği. Ayarlar'daki galeriden seçin, sürükleyerek sıralayın; yeni kurulum yalnızca üçüyle başlar.
- **İsteğe bağlı ekstralar** (siz açana kadar kapalı): paneli istediğiniz ekranda gösterme, ses ve parlaklık düzeyini notch'ta gösterme (isterseniz sistem göstergelerinin yerine), mikrofon veya kamera kullanılırken bir nokta, toplantılardan önce geri sayım, medya kaynağı seçimi ve [kendi script'leriniz için bir API](#scriptler).
- **Canlı etkinlikler**: çalışan zamanlayıcı, bekleyen Claude isteği, şarj veya çalan şarkı kapalı notch'un iki yanında görünür.
- **Temalar**: düz siyah ve Liquid Glass'tan Neon Tokyo, Sakura ve Synthwave'e yedi hazır tema. Kendi temanızı yapın: cam, düz veya renkli cam, renk geçişli zemin, neon kenar, renkler, yazı tipi, yazı boyutu, panel boyutu, köşe yuvarlaklığı, gölge ve animasyon. Temaları JSON olarak içe/dışa aktarın.
- **Yolunuza çıkmaz**: tıklamalar menü çubuğuna geçer, pencere sürüklerken panel açılmaz, tam ekran uygulamalarda gizlenir ve boşta CPU kullanımı sıfırdır. Ayarlar için notch'a sağ tıklayın.
- Türkçe ve İngilizce arayüz.

<a name="indirme"></a>

## İndirme ve kurulum

1. [Son sürümden](https://github.com/muazfurkan/Cumba/releases/latest) `Cumba-vX.Y.Z.dmg` (ya da `.zip`) dosyasını indirin.
2. **Açmadan önce dosyayı doğrulayın.** SHA-256 değeri, sürüm sayfasındaki `SHA256SUMS.txt` ile aynı olmalı:
   ```bash
   shasum -a 256 ~/Downloads/Cumba-vX.Y.Z.dmg
   ```
   1.1.0'dan itibaren sürümler ayrıca değiştirilemezdir (yayımlandıktan sonra dosyaları ve etiketi değişemez) ve imzalı derleme kaynağı (build provenance) taşır. [GitHub CLI](https://cli.github.com) ile dosyanın bu reponun yayın iş akışında derlendiğini doğrulayabilirsiniz:
   ```bash
   gh attestation verify ~/Downloads/Cumba-vX.Y.Z.dmg --repo muazfurkan/Cumba
   ```
3. Disk görüntüsünü açın ve Cumba'yı Uygulamalar klasörüne sürükleyin.
4. Cumba Apple tarafından notarize edilmedi, çünkü bu ücretli bir geliştirici hesabı gerektiriyor; bu yüzden macOS ilk açılışı engeller. Bir kez açmayı deneyin, ardından **Sistem Ayarları > Gizlilik ve Güvenlik**'te **Yine de Aç**'a tıklayın. İndirilmiş bir derlemeyi hiç çalıştırmak istemezseniz [kaynaktan derleyin](#kaynaktan-derleme).
5. Kısa bir karşılama penceresi paneli denemenizi sağlar. Cumba menü çubuğunda yaşar; simgesi notch'un arkasında kalırsa Ayarlar için notch'a sağ tıklayın.

<details>
<summary>Yine de Aç yerine Terminal</summary>

`xattr -dr com.apple.quarantine /Applications/Cumba.app` yalnızca bu uygulamadaki indirme işaretini kaldırır, Gatekeeper da sormayı bırakır. Bunu yalnızca 2. adımda doğruladığınız bir kopya için yapın.
</details>

**Güncellemeler:** Uygulama yeni sürüm çıktığında haber verir; kendi başına hiçbir şey indirmez veya kurmaz. Sürümler ad-hoc imzalı olduğu için güncellemeden sonra macOS verdiğiniz izinleri (Otomasyon, Takvim, Konum, Kamera) ve Cumba'nın token'ları için Anahtar Zinciri erişimini yeniden sorar. Önce yeni dosyayı doğrulayın, sonra izin verin.

**ljaspNotch'tan mı geçiyorsunuz?** Cumba aynı uygulamanın yeni adı. ljaspNotch'tan çıkın, `ljaspNotch.app`'i Çöp Sepeti'ne taşıyın ve Cumba'yı kurun; ayarlarınız, düzeniniz, notlarınız ve temalarınız aynen gelir. Claude Code hook'larını kullanıyorsanız Ayarlar > Claude Code'da bir kez **Güncelle…**'ye tıklayın. Chrome eklentisini kullanıyorsanız onu `chrome://extensions` sayfasından kaldırın, [YouTube ve YouTube Music](#youtube-ve-youtube-music) bölümündeki gibi yeni uygulamadan tekrar yükleyin ve token'ı yapıştırın.

## Gereksinimler

- Notch'lu bir Mac (diğer Mac'ler sanal notch gösterebilir, bkz. Ayarlar > Genel)
- macOS 26 veya üstü

## Kaynaktan derleme

Xcode 26 veya üstü ve [Homebrew](https://brew.sh) gerekir.

```bash
brew install xcodegen
git clone https://github.com/muazfurkan/Cumba.git
cd Cumba
cp Local.xcconfig.example Local.xcconfig   # ardından DEVELOPMENT_TEAM değerini gir
xcodegen generate
open Cumba.xcodeproj
```

Ayrıntılar için [CONTRIBUTING.md](CONTRIBUTING.md) dosyasına bakın.

<a name="izinler"></a>

## İzinler ve neler çalışır

Aşağıdakilerin hepsi, gerektiren özelliği açana kadar kapalıdır veya kullanılmaz. Her birinin güncel durumu Ayarlar > İzinler'de görünür.

| Ne | Neden | Ne zaman |
|---|---|---|
| Sistemin Şu An Çalan yardımcısı | Her uygulamadaki medya ve kontrolleri | Uygulama açıkken çalışır; yerine AppleScript kullanmak için "Medyayı her uygulamadan oku"yu kapatın. Bkz. [aşağısı](#medya-ve-ozel-apiler) |
| Spotify ve Müzik için Otomasyon (Apple Events) | Çalan parçayı okumak; oynat, duraklat, atla, sar | Yalnızca "Medyayı her uygulamadan oku" kapalıyken; Ayarlar'dan istenir, komutlar yalnızca o uygulama zaten açıkken gönderilir |
| Takvim (tam erişim) | Takvim widget'ı | Widget'ta veya Ayarlar'da İzin Ver'e tıkladığınızda istenir |
| Konum | Hava durumu widget'ı, bulunduğunuz yerin havası için | Konumumu Kullan'a tıkladığınızda istenir; şehir seçerseniz kullanılmaz |
| Kamera | Ayna widget'ı | Yalnızca panel onu gösterirken; hiçbir şey kaydedilmez |
| `127.0.0.1` üzerinde yerel sunucu | İsteğe bağlı YouTube eklentisi bağlantısı | Yalnızca Ayarlar > Bağlantılar'dan açtıktan sonra |
| Özel Unix soketi | Claude Code hook'ları ve [script etkinlikleri](#scriptler) | Yalnızca hook'lar kuruluyken veya script etkinlikleri açıkken |
| `~/.claude/settings.json`, `~/.codex/hooks.json` | Claude Code ve Codex hook'larını kurmak ve kaldırmak | Yalnızca değişikliği gözden geçirdikten sonra; yedek alınır |
| `~/.claude/projects` içindeki Claude Code oturum kayıtları | Yapay Zeka Ajanları widget'ında bağlam kullanımı ve oturum başlığı | Yalnızca bu Mac'te, son 256 KB, oturum sürerken okunur |
| Erişilebilirlik | Ses veya parlaklık tuşlarını yönetmek | Yalnızca "Sistemin ses göstergesinin yerine geç" veya "…parlaklık göstergesinin…" açıksa |
| Pano | Pano Geçmişi widget'ı | Yalnızca o widget paneldeyken |
| Giriş öğesi | Oturum açıldığında başlatma | Siz açana kadar kapalı |
| Ağ | Kapak görselleri, hava durumu, güncelleme kontrolü | Bkz. [Gizlilik](#gizlilik) |

App Sandbox kapalı: sandbox'taki bir uygulama Spotify ve Müzik'i komutla yönetmek, Claude Code hook'larının ulaştığı soketi çalıştırmak ve `~/.claude/settings.json` dosyasını düzenlemek için istisnalara ihtiyaç duyar. Hardened Runtime açık ve uygulamanın yalnızca [Cumba.entitlements](Cumba/Resources/Cumba.entitlements) dosyasındaki yetkileri var (Apple Events, takvim, konum, kamera).

Cumba hiçbir zaman telemetri göndermez, yönetici parolası istemez, yardımcı araç, çekirdek veya sistem uzantısı kurmaz, sistem ayarlarını değiştirmez, kod indirmez ve kendini güncellemez. Tehdit modeli ve güvenlikle ilgili kodun haritası [SECURITY.md](SECURITY.md) dosyasında.

<a name="medya-ve-ozel-apiler"></a>

## Medya, parlaklık ve özel API'ler

macOS'ta bir uygulamanın diğer uygulamaların ne çaldığını görmesinin ya da Apple silicon'da dahili ekranın parlaklığını okumasının açık bir yolu yok. Cumba yalnızca bunlar için iki özel Apple çerçevesi kullanır, başka hiçbir şey için değil:

- **MediaRemote**, sistemin Şu An Çalan bilgisi (medya tuşlarının ve Denetim Merkezi'nin kullandığı). macOS bunu yalnızca Apple'ın kendi programlarına yanıtlar; bu yüzden Cumba kendi uygulama paketindeki küçük bir yardımcı kitaplığı ([kaynak](NowPlayingHelper/CumbaNowPlaying.m)) sistemin `/usr/bin/perl`'ü içinde, boş bir ortamla çalıştırır. Yardımcı yalnızca Şu An Çalan'ı okur ve oynat, duraklat, atla ve sar komutlarını iletir; hiçbir dosya ya da ağ bağlantısı açmaz ve Cumba kapanınca çıkar. Bunun yerine Spotify ve Müzik için AppleScript'i, YouTube için eklentiyi kullanmak isterseniz **Ayarlar > Widget'lar > Medya > Medyayı her uygulamadan oku**'yu kapatın.
- **DisplayServices**, notch'taki parlaklık düzeyi için. Yalnızca Ayarlar > Genel'de parlaklık değişikliklerini açtığınızda yüklenir.

Özel API'ler herhangi bir macOS güncellemesiyle değişebilir. Çalışmayı bırakırlarsa Cumba yukarıdaki açık yollara geri döner ve çalışmaya devam eder.

## YouTube eklentisi (isteğe bağlı)

Medya her uygulamadan okurken gerekmez. Küçük bir Chrome eklentisi (diğer Chromium tarayıcılarda da çalışır) YouTube sekmelerinde çalanı yerel bir bağlantı üzerinden uygulamaya gönderir; uygulama da oynat, duraklat, sonraki ve sarma komutlarını geri yollar.

1. Cumba'da **Ayarlar > Bağlantılar**'ı açın, **YouTube eklentisini bağla**'yı açın ve **Eklenti Klasörünü Göster**'e tıklayın.
2. Chrome'da `chrome://extensions` adresini açın, **Geliştirici modu**'nu etkinleştirin ve **Paketlenmemiş öğe yükle**'ye tıklayın. 1. adımdaki klasörü seçin.
3. Eklentinin **Ayrıntılar > Eklenti seçenekleri** sayfasını açın, **Ayarlar > Bağlantılar**'daki portu ve token'ı yapıştırıp kaydedin.

Chrome, eklentinin `youtube.com` ve `music.youtube.com` üzerindeki verilerinizi okuyup değiştirebileceğini söyler: eklenti oynatıcıyı okur (başlık, kapak, ilerleme) ve orada oynat, duraklat, sonraki ve sarma düğmelerine basar. Başka hiçbir sitede çalışmaz, tek diğer izni depolamadır (port ve token için) ve yalnızca `127.0.0.1` ile konuşur.

## Claude Code

Claude Code'un (terminal, IDE eklentileri ve Claude masaüstü uygulaması) izin istekleri **İzin Ver**, **Reddet** ve **Terminalde** seçenekleriyle notch'ta görünür; bir oturum bitince veya hata verince de görürsünüz. Kart, isteğin tamamını gizli karakterleri görünür hale getirerek gösterir. Hook'ları **Ayarlar > Claude Code**'dan kurun; `~/.claude/settings.json` değişikliğini önce siz görürsünüz ve yedek alınır. Hook'lar uygulamaya yalnızca sizin kullanıcı hesabınızın açabildiği özel bir soket üzerinden ulaşır; böylece başka hiçbir şey Claude Code'a uygulama adına cevap veremez; hook'lar eklentininkinden ayrı, kendi token'larını kullanır.

**Notch'taki İzin Ver, Claude Code'daki İzin Ver ile aynıdır: araç hemen çalışır.** Ayarlar > Claude Code'dan notch'ta kabuk komutları dışındaki her şeye izin verilmesini seçebilir ya da İzin Ver'i tamamen kapatıp yalnızca Reddet ve Terminalde seçeneklerini bırakabilirsiniz. Gizli karakter içeren isteklerde İzin Ver düğmesi hiç gösterilmez. Ayrıntılar ve elle kurulum için [docs/claude-code-setup.md](docs/claude-code-setup.md) dosyasına bakın.

<a name="scriptler"></a>


**Codex** de aynı şekilde çalışır: hook'larını **Ayarlar > Ajanlar > Codex**'ten kurun (`~/.codex/hooks.json` dosyasına yazılır), ardından Codex'te bir kez `/hooks` komutunu çalıştırıp onlara güvenin; Codex yeni hook'ları ancak bundan sonra çalıştırır.
## Script'ler

Kendi script'lerinizin, Kısayollar'ın veya derleme araçlarınızın notch'un yanında kısa bir durum göstermesi için **Ayarlar > Bağlantılar > Script'ler**'i açın. **Örnek Komutu Kopyala**, token'ınızla çalışmaya hazır bir komut kopyalar:

```bash
curl -s --unix-socket "$HOME/Library/Application Support/Cumba/hook.sock" \
  -H "X-Cumba-Token: <token>" -H "Content-Type: application/json" \
  -d '{"id":"build","title":"Build done","symbol":"hammer","duration":5}' \
  http://localhost/activity
```

Alanlar: `id` (harf, rakam, `.`, `_` ve `-`), `title` (en fazla 60 karakter), `symbol` (bir SF Symbol adı), `progress` (0 ile 1 arası, çubuk gösterir), `duration` (saniye, 1–3600) ve bir etkinliği kaldırmak için `"remove": true`. Etkinlikler yalnızca metindir, Claude Code istekleri gibi kaçışlanır ve içlerinde tıklanabilecek bir şey yoktur.

## Gizlilik

Telemetri yok. Her şey Mac'inizde kalır. Şu özellikler ağ isteği yapar, yalnızca siz kullanırken:

| Özellik | İstek |
|---|---|
| Spotify ile medya widget'ı | Spotify'ın görsel sunucusundan (`i.scdn.co`) kapak görseli |
| YouTube ile medya widget'ı | YouTube'un görsel sunucularından küçük resim (sayfanın kendi kullandığı adres) |
| Hava durumu widget'ı | Yaklaşık 10 km'ye yuvarlanmış konumunuz (ya da seçtiğiniz şehrin koordinatları) `api.open-meteo.com`'a; konumunuzla birlikte şehir adı için aynı yuvarlanmış koordinatlar Apple Haritalar'a; aradığınız şehir adı `geocoding-api.open-meteo.com`'a |
| Güncelleme denetimi | Açılışta ve günde bir kez `api.github.com`'dan sürüm listesi; Ayarlar > Genel'den kapatılabilir |

Kamera (Ayna widget'ı) yalnızca panel onu gösterirken çalışır ve hiçbir şey kaydedilmez. Raf yalnızca dosya yollarını Mac'inizde tutar. Notlar `~/Library/Application Support/Cumba/notes.txt` içinde düz metin olarak saklanır. Pano Geçmişi kopyaladığınız son 20 metni yalnızca bellekte tutar ve uygulamaların parola olarak işaretlediği öğeleri almaz; paneldeyken panonun değişip değişmediğini saniyede bir kontrol eder. Mikrofon ve kamera göstergesi yalnızca bir cihazın kullanımda olup olmadığını okur; sese veya görüntüye asla erişmez.

Açıldığında eklenti sunucusu yalnızca `127.0.0.1` adresini dinler, yalnızca Cumba eklentisini kabul eder ve Anahtar Zinciri'nde saklanan kendi token'ını ister.

## Kaldırma

1. Claude Code hook'larını kurduysanız önce **Ayarlar > Claude Code > Kaldır…** ile kaldırın. Uygulama silindikten sonra kalan hook'lar hiçbir şey yapmaz ama `~/.claude/settings.json` içinde kalır.
2. Ayarlar > Genel'de **Oturum açıldığında başlat**'ı kapatın, menü çubuğundan Cumba'dan çıkın ve uygulamayı Çöp Sepeti'ne taşıyın.
3. Eklentiyi `chrome://extensions` sayfasından kaldırın.
4. Verilerini de silmek için (temalar, düzen, notlar, tercihler ve token'lar):
   ```bash
   rm -rf ~/Library/Application\ Support/Cumba
   defaults delete io.github.muazfurkan.ljaspnotch
   security delete-generic-password -s io.github.muazfurkan.ljaspnotch.server -a token
   security delete-generic-password -s io.github.muazfurkan.ljaspnotch.server -a extension-token
   security delete-generic-password -s io.github.muazfurkan.ljaspnotch.server -a scripts-token
   ```
   Hook kurulumunda alınan Claude Code ayar yedekleri `~/.claude/settings.json.bak-…` adıyla yanında durur; saklayabilir ya da silebilirsiniz.

## Katkı

Sorular ve fikirler için [Discussions](https://github.com/muazfurkan/Cumba/discussions) bölümünü kullanabilirsiniz. Katkılara da açığız; lütfen [CONTRIBUTING.md](CONTRIBUTING.md) ve [Davranış Kuralları](CODE_OF_CONDUCT.md) belgelerini okuyun. Güvenlik açıklarını [SECURITY.md](SECURITY.md) dosyasında anlatıldığı gibi gizli olarak bildirin.

## Lisans

[MIT](LICENSE)
