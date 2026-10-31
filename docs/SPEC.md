# ljaspNotch: Teknik Spesifikasyon

Sürüm 0.1 · Ekim 2026 · Durum: taslak

Bu belge Claude Code ile geliştirme için tek doğruluk kaynağıdır. Bir karar değişirse önce bu belge güncellenir.

---

## 1. Amaç

MacBook notch'unu, üzerine gelince ya da tıklayınca genişleyen bir panele çeviren açık kaynak bir macOS uygulaması. NotchNook'tan ilham alır ama üç noktada ondan ayrılır:

1. Tarayıcıda çalan **YouTube ve YouTube Music** notch'ta mini oynatıcı olarak görünür.
2. **Claude Code** bildirimleri ve izin onayları notch'tan yönetilir.
3. Görünüm, boyut ve widget düzeni **tamamen kullanıcıya göre** ayarlanabilir.

## 2. Kapsam

**Kapsamda**
- Notch'lu MacBook'lar, macOS 26 ve sonrası.
- Spotify, Apple Music, YouTube / YouTube Music (Chrome ve Chromium tabanlı tarayıcılar).
- Claude Code: terminal, IDE eklentileri ve Claude masaüstü uygulamasındaki Code oturumları.
- Widget sistemi, tema sistemi, Türkçe + İngilizce arayüz.

**Kapsam dışı (v1.0)**
- Claude sohbet uygulamasının bildirimleri. macOS, bir uygulamanın başka uygulamaların bildirimlerini okumasına izin vermiyor.
- Safari ve Firefox eklentileri (ileride değerlendirilebilir).
- Sistemin ses/parlaklık göstergesinin değiştirilmesi.
- App Store dağıtımı, notch'suz Mac'lerde tam destek (yalnızca isteğe bağlı "sanal notch").

## 3. Gereksinimler

### Fonksiyonel
| No | Gereksinim |
|---|---|
| F1 | Notch, imleç üstüne gelince (veya ayara göre tıklayınca) animasyonla genişler, imleç ayrılınca kapanır. Panel sabitlenebilir. |
| F2 | Panelin genişliği, yüksekliği, köşe yuvarlaklığı ve açılma/kapanma gecikmeleri ayarlanabilir. |
| F3 | Tarayıcıda YouTube / YouTube Music çalınca başlık, kanal/sanatçı, kapak, ilerleme ve oynat/durdur/ileri/geri/sarma kontrolleri notch'ta görünür. |
| F4 | Spotify ve Apple Music aynı mini oynatıcıda, aynı kontrollerle görünür. |
| F5 | Claude Code izin istediğinde notch'ta görünür; kullanıcı notch'tan onaylar, reddeder veya terminale yönlendirir. İş bitince ve hata olunca kısa bildirim gösterilir. |
| F6 | Tema sistemi: materyal (Liquid Glass / düz siyah / renkli cam), renkler, yazı tipi stili, animasyon. Hazır temalar + kullanıcı temaları, içe/dışa aktarma. |
| F7 | Widget sistemi: widget'lar sekmelere yerleştirilir, sıralanır, açılıp kapatılır. Her widget'ın kendi ayarları olabilir. |
| F8 | Kapalı notch'ta "canlı etkinlikler": çalan şarkı, bekleyen Claude onayı, zamanlayıcı, şarj durumu notch'un iki yanında küçük göstergelerle görünür. |
| F9 | Menü çubuğu simgesi: Ayarlar, Duraklat, Çık. Girişte otomatik başlatma seçeneği. |

### Fonksiyonel olmayan
| No | Gereksinim |
|---|---|
| N1 | Boşta CPU kullanımı < %1, bellek < 120 MB. |
| N2 | Ana thread asla bloklanmaz (I/O, AppleScript, ağ ana thread dışında). 100 kez aç/kapa sonrası donma yok. |
| N3 | Uyku/uyanma, harici monitör tak/çıkar ve çözünürlük değişiminden sonra panel doğru konumda. |
| N4 | Telemetri yok. Claude Code verileri yalnızca bellekte tutulur. |
| N5 | VoiceOver etiketleri tüm kontrollerde mevcut. |
| N6 | Temiz bir klondan `xcodegen generate` + `xcodebuild` ile derlenebilir. |

## 4. Mimari

```
┌─────────────────────────── ljaspNotch.app ───────────────────────────┐
│  MenuBarController        SettingsWindow                         │
│                                                                  │
│  NotchWindowController ─── NotchViewModel (durum makinesi)       │
│          │                        │                              │
│     NotchPanel (NSPanel)     LiveActivityCenter                  │
│          │                        │                              │
│     NotchRootView (SwiftUI) ── WidgetHost ── [Widget'lar]        │
│                                                                  │
│  Servisler                                                       │
│    MediaCoordinator ──┬── SpotifyProvider                        │
│                       ├── AppleMusicProvider                     │
│                       └── BrowserProvider ◄────────────┐         │
│    ClaudeCodeService ── PermissionBroker ◄───────┐     │         │
│    ThemeStore · LayoutStore · AppSettings        │     │         │
│                                                  │     │         │
│  LocalServer (127.0.0.1, FlyingFox) ─────────────┴─────┘         │
└──────────────────────────────────────────────────────────────────┘
          ▲ HTTP POST (hook)                    ▲ WebSocket
   Claude Code (CLI / IDE / Desktop)     Chrome eklentisi (youtube.com, music.youtube.com)
```

Temel ilkeler:
- **Görünüm ile veri ayrı:** Widget'lar servisleri dinler, servisler widget'ları bilmez.
- **Olay tabanlı:** Servisler `@Observable` modeller yayınlar; zamanlayıcıyla yoklama yalnızca son çare.
- **Gevşek bağlı sağlayıcılar:** Yeni bir medya kaynağı eklemek için yalnızca `MediaProvider` protokolünü uygulamak yeterli.

## 5. Repo yapısı

```
ljaspNotch/
├── CLAUDE.md
├── README.md                  # İngilizce
├── README.tr.md               # Türkçe
├── LICENSE                    # MIT
├── CONTRIBUTING.md
├── CHANGELOG.md
├── SECURITY.md                # güvenlik açığı bildirme politikası
├── CODE_OF_CONDUCT.md         # Contributor Covenant
├── project.yml                # XcodeGen
├── Local.xcconfig.example     # DEVELOPMENT_TEAM buraya, kopyası gitignore'da
├── .editorconfig              # indent_size = 2
├── .swift-format              # indentation: 2 spaces
├── .gitignore
├── .github/
│   ├── workflows/build.yml    # her push/PR: derle + test
│   ├── workflows/release.yml  # v* etiketi: derle, imzala (ad-hoc), zip, GitHub Release
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/        # bug_report.yml, feature_request.yml
├── docs/
│   ├── SPEC.md
│   └── claude-code-setup.md
├── ljaspNotch/
│   ├── App/          # LjaspNotchApp, AppDelegate, MenuBarController, AppSettings
│   ├── Notch/        # NotchPanel, NotchWindowController, NotchGeometry, NotchViewModel, HoverTracker
│   ├── Widgets/
│   │   ├── Core/     # NotchWidget, WidgetRegistry, LayoutStore, LiveActivity, LiveActivityCenter
│   │   ├── Media/  Calendar/  ClaudeCode/  Battery/  Timer/
│   │   └── Tray/  Mirror/  Weather/  Shortcuts/  SystemStats/  Lyrics/
│   ├── Media/        # NowPlaying, MediaProvider, MediaCoordinator, Providers/
│   ├── Claude/       # ClaudeCodeService, HookPayload, PermissionBroker, HookInstaller
│   ├── Server/       # LocalServer, TokenStore, Routes
│   ├── Theme/        # Theme, ThemeStore, BuiltInThemes/
│   ├── Settings/     # SettingsView ve sekmeleri
│   └── Resources/    # Assets.xcassets, Localizable.xcstrings, Info.plist, ljaspNotch.entitlements
├── ljaspNotchTests/
│   └── Fixtures/     # gerçek hook payload örnekleri (kişisel veriden arındırılmış)
└── extensions/
    └── chrome/       # manifest.json, background.js, content.js, selectors.js, options.html, options.js
```

## 6. Notch penceresi

### Geometri
- Notch var mı: `NSScreen.safeAreaInsets.top > 0`.
- Notch genişliği: `screen.frame.width - auxiliaryTopLeftArea.width - auxiliaryTopRightArea.width`. Yüksekliği: `safeAreaInsets.top`.
- `NotchGeometry` saf bir struct olur (ekran değerlerini alır, frame'leri döner) ve birim testlerle doğrulanır.
- Notch'suz ekran için ayar: "Sadece dahili ekran" (varsayılan) / "Ana ekranda sanal notch".

### Pencere
- `NSPanel`, `styleMask: [.borderless, .nonactivatingPanel]`, `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false`.
- Seviye menü çubuğunun üstünde (`.statusBar` üstü; Faz 1'de doğrulanır).
- `collectionBehavior: [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`.
- **Pencere boyutu sabit** (açık halin en büyük boyutu + gölge payı). Açılma/kapanma animasyonu SwiftUI içinde şekil olarak yapılır; pencere frame'i her karede değiştirilmez. Bu hem akıcılık hem stabilite için.
- Tıklama geçişi: Panelin görünür şekli dışındaki alanlar fare olaylarını almaz (hit-test override veya dinamik `ignoresMouseEvents`). Panel kapalıyken menü çubuğu öğeleri tıklanabilir kalır.
- Panel ancak metin girişi gerektiğinde key window olur (`canBecomeKey` yalnızca o durumda `true`). Esc ile kapanır.

### Durum makinesi (`NotchViewModel`)
| Durum | Görünüm | Giriş | Çıkış |
|---|---|---|---|
| `closed` | Notch boyutunda, görünmez kadar sade | Varsayılan | Hover/tık → `expanded`; canlı etkinlik → `peek` |
| `peek` | Notch'un iki yanında küçük göstergeler | Canlı etkinlik başladı | Etkinlik bitti → `closed`; hover → `expanded` |
| `expanded` | Tam panel, sekmeler ve widget'lar | Hover (gecikmeli) veya tık | İmleç ayrıldı (gecikmeli) → önceki durum |
| `pinned` | `expanded` gibi ama kapanmaz | Sabitle butonu | Sabitlemeyi kaldır |

- Varsayılan gecikmeler: açılma 0,15 sn, kapanma 0,4 sn. İkisi de ayarlanabilir.
- Ayar: "Tam ekran uygulamada gizle" (varsayılan açık).
- Yeniden konumlama tetikleyicileri: `NSApplication.didChangeScreenParametersNotification`, `NSWorkspace.didWakeNotification`, `NSWorkspace.activeSpaceDidChangeNotification`.

## 7. Widget sistemi

### Protokol (taslak)
```swift
@MainActor
protocol NotchWidget: AnyObject, Identifiable {
  static var kind: String { get }        // "media", "calendar", ...
  var id: UUID { get }
  var title: LocalizedStringResource { get }
  var size: WidgetSize { get }
  func makeView() -> AnyView
  func makeSettingsView() -> AnyView?
  // Panel görünürken çağrılır; kamera, zamanlayıcı gibi kaynaklar yalnızca burada açılır
  func activate()
  func deactivate()
}

enum WidgetSize: String, Codable {
  case compact   // 1 birim
  case regular   // 2 birim
  case wide      // 3 birim
}
```
- `WidgetRegistry`: `kind` → fabrika eşlemesi. Yeni widget = yeni klasör + registry'ye tek satır.
- Widget'lar canlı etkinliklerini `LiveActivityCenter`'a kendileri bildirir.

### Düzen (`LayoutStore`)
`~/Library/Application Support/ljaspNotch/layout.json` içinde saklanır:
```json
{
  "version": 1,
  "tabs": [
    { "id": "home", "title": "Home", "symbol": "house", "widgets": ["media", "calendar", "claude-code"] },
    { "id": "tray", "title": "Tray", "symbol": "tray", "widgets": ["tray"] }
  ]
}
```

### Canlı etkinlik öncelikleri
Aynı anda birden fazla etkinlik varsa yüksek öncelikli olan gösterilir:
1. Bekleyen Claude Code izin isteği
2. Biten zamanlayıcı
3. Claude Code iş bitti / hata (4 sn)
4. Şarj başladı / batarya düşük (3 sn)
5. Çalan medya (sürekli)

### Widget kataloğu
| Widget | Faz | Zorluk | Not |
|---|---|---|---|
| Media | 4–5 | Orta | § 8 |
| Claude Code | 6 | Orta | § 9 |
| Calendar | 3 | Kolay | EventKit, bugünün ve yarının etkinlikleri |
| Battery | 3 | Kolay | IOKit güç kaynağı bildirimleri |
| Timer / Pomodoro | 3 | Kolay | Bitince canlı etkinlik + ses |
| Tray (dosya rafı) | 7 | Orta | Sürükle-bırak, AirDrop için `NSSharingService` |
| Mirror (kamera) | 7 | Kolay | AVFoundation, yalnızca panel açıkken çalışır |
| Weather | 7 | Kolay | Open-Meteo (ücretsiz, anahtarsız). WeatherKit ücretli hesap istediği için kullanılmaz |
| Shortcuts | 7 | Kolay | Kısayollar uygulamasındaki kısayolları `shortcuts run` ile çalıştırır |
| System Stats | 7 | Kolay | CPU/RAM mini grafik, yalnızca panel açıkken örnekler |
| Lyrics | 9 | Orta | LRCLIB (ücretsiz) üzerinden senkron şarkı sözü, opsiyonel |
| AirPods | 9 | Zor | Batarya bilgisi için genel API yok, araştırma gerekir |

## 8. Medya

### Model
```swift
struct NowPlaying: Equatable, Sendable {
  enum Source: String, Sendable { case spotify, appleMusic, youtube, youtubeMusic }
  var source: Source
  var title: String
  var artist: String?
  var album: String?
  var artworkURL: URL?
  var artworkData: Data?
  var duration: TimeInterval?
  var position: TimeInterval?
  var positionTimestamp: Date     // ilerleme çubuğu bu andan itibaren yerelde ilerletilir
  var isPlaying: Bool
}

protocol MediaProvider: AnyObject, Sendable {
  var source: NowPlaying.Source { get }
  var updates: AsyncStream<NowPlaying?> { get }
  func send(_ command: MediaCommand) async
}

enum MediaCommand: Sendable {
  case togglePlayPause, next, previous
  case seek(TimeInterval)
}
```

### Koordinatör kuralları (`MediaCoordinator`)
- Çalan kaynak varsa o gösterilir. Birden fazla kaynak çalıyorsa en son oynatmaya başlayan kazanır.
- Hiçbiri çalmıyorsa son duraklatılan 10 dakika boyunca gösterilir, sonra medya alanı gizlenir.
- Kullanıcı panelden kaynaklar arasında elle geçiş yapabilir.
- İlerleme çubuğu saniyede bir yeniden sorgulanmaz; `position + (now - positionTimestamp)` ile yerelde hesaplanır.

### Spotify ve Apple Music
- Değişiklikleri dağıtık bildirimlerle dinle: Spotify `com.spotify.client.PlaybackStateChanged`, Apple Music `com.apple.Music.playerInfo`. `userInfo` alanları Faz 4'te macOS 26 üzerinde doğrulanır.
- Kontrol ve eksik bilgiler (konum, kapak) AppleScript ile alınır. Spotify kapak için URL verir, Apple Music görsel verisinin kendisini verir.
- **Kural:** Komut göndermeden önce `NSRunningApplication` ile uygulamanın çalıştığını kontrol et. Kapalı uygulamaya AppleScript gönderilirse uygulama açılır.
- AppleScript çağrıları tek bir actor üzerinden, ana thread dışında çalışır.

### YouTube ve YouTube Music (Chrome eklentisi)
**Eklenti yapısı (Manifest V3)**
- `content.js`: `https://www.youtube.com/*` ve `https://music.youtube.com/*` sayfalarında çalışır.
  - Veri: `navigator.mediaSession.metadata` (başlık, sanatçı, kapak) + sayfadaki `<video>` elementi (`currentTime`, `duration`, `paused`).
  - Olaylar: `play`, `pause`, `loadedmetadata`, `seeked` ve kısıtlı `timeupdate` (en fazla 1 sn'de bir). Şarkı/video değişince hemen gönderir.
  - Komutlar: oynat/durdur ve sarma doğrudan `<video>` üzerinden. İleri/geri için sayfadaki butonlar kullanılır.
  - **Tüm DOM seçicileri `selectors.js` içinde tek yerde** durur; YouTube arayüzü değişince yalnızca o dosya güncellenir.
- `background.js` (service worker): Sekmelerden gelen durumları toplar, uygulamaya tek bir WebSocket bağlantısıyla iletir. Bağlantı koparsa artan aralıklarla yeniden bağlanır, 20 sn'de bir ping atar.
- `options.html`: Port ve token girişi.
- Kurulum v1.0'da "Paketlenmemiş öğe yükle" ile yapılır (README'de anlatılır). Chrome Web Store ayrı bir karardır.

**Mesaj protokolü** (`ws://127.0.0.1:<port>/media`, JSON)
```json
{ "type": "hello", "version": 1, "token": "<token>" }
```
```json
{
  "type": "state",
  "tabId": 812,
  "site": "youtubeMusic",
  "title": "Song Title",
  "artist": "Artist",
  "album": "Album",
  "artworkUrl": "https://...",
  "videoId": "abc123",
  "duration": 215.3,
  "position": 42.1,
  "isPlaying": true,
  "sentAt": 1793380000000
}
```
```json
{ "type": "closed", "tabId": 812 }
```
Uygulamadan eklentiye:
```json
{ "type": "command", "tabId": 812, "action": "seek", "position": 90 }
```
`action`: `toggle` | `play` | `pause` | `next` | `previous` | `seek`.

### Deneysel: video önizleme (Faz 9)
Kapak yerine videonun kendisini küçük pencerede göstermek. İki yol denenir:
1. Eklentinin `<video>` karesini düşük hızda (2–5 fps) canvas'a çizip göndermesi. Ekran Kaydı izni gerektirmez, ama YouTube videolarında canvas'ın kilitlenip kilitlenmediği (cross-origin) test edilmeli.
2. ScreenCaptureKit ile tarayıcı penceresinden ilgili alanı yakalamak. Ekran Kaydı izni gerektirir.
Varsayılan kapalı bir ayar olarak eklenir.

## 9. Claude Code entegrasyonu

### Yaklaşım
Claude Code'un **HTTP hook** desteği kullanılır: Claude Code belirli olaylarda olay verisini JSON olarak uygulamanın lokal sunucusuna POST eder, uygulama gerekirse cevap gövdesinde karar döner. Ara bir script gerekmez. Hook'lar terminal, IDE eklentileri ve Claude masaüstü uygulamasındaki Code oturumlarında aynı şekilde çalışır.

Referans: https://code.claude.com/docs/en/hooks (alan adları ve davranışlar uygulama sırasında buradan doğrulanır).

### Kullanılan olaylar
| Olay | Amaç | Timeout (sn) |
|---|---|---|
| `UserPromptSubmit` | Oturumu "çalışıyor" olarak işaretle (yoksa oluştur) | 5 |
| `PermissionRequest` | İzin isteğini notch'ta göster, kararı dön | 300 |
| `Notification` | "Claude seni bekliyor" gibi durumlar (`idle_prompt`, `agent_needs_input` vb.) | 5 |
| `Stop` | "İş bitti" bildirimi (`last_assistant_message` alanından kısa özet) | 5 |
| `StopFailure` | Hata bildirimi (rate limit, sunucu hatası vb.) | 5 |
| `SessionEnd` | Oturumu listeden kaldır | 2 |

Notlar:
- `SessionStart` HTTP hook desteklemediği için kullanılmaz; oturum ilk `UserPromptSubmit`'te oluşturulur.
- `UserPromptSubmit` modeli bloklar; sunucu bu olaya **anında** boş 200 döner.
- `Notification` içindeki `permission_prompt` türü, zaten bekleyen bir `PermissionRequest` varsa arayüzde tekrar gösterilmez.
- **Hiçbir hook'ta `onFailure: "block"` kullanılmaz.** Uygulama kapalıysa bağlantı hatası Claude Code tarafında engelleyici olmayan bir hata sayılır ve normal akış (terminaldeki izin diyaloğu) devam eder.

### Oturum modeli
- Anahtar: `session_id`. Gösterilen ad: `cwd`'nin son klasör adı (örn. `ljaspNotch`).
- Durumlar: `working` → `waitingPermission` → `working` → `done` / `failed` → (SessionEnd) `ended`.
- `ended` oturumlar 1 dk sonra listeden düşer. Hiçbir veri diske yazılmaz.

### İzin akışı (`PermissionBroker`)
1. `PermissionRequest` gelir. Broker isteği kuyruğa alır ve HTTP cevabını bekletir.
2. Notch `peek` durumuna geçer: proje adı, araç adı ve kısa özet (Bash → komut, Edit/Write → dosya yolu, diğerleri → araç adı). Uzun metinler kısaltılır.
3. Kullanıcının seçenekleri ve dönülen cevap:

| Seçim | HTTP cevabı |
|---|---|
| Onayla | `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}` |
| Reddet | `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}` |
| Terminalde yanıtla | Boş gövdeli 200 → Claude Code normal izin akışına devam eder |
| Süre doldu | Hook timeout'undan 10 sn önce boş gövdeli 200 döner |

4. Aynı anda birden fazla istek varsa sırayla gösterilir, notch'ta bekleyen sayısı rozet olarak görünür.

### Kurulum yardımcısı (`HookInstaller`)
- Ayarlar → Claude Code sekmesi: durum (kurulu / değil / güncel değil), **Kur** ve **Kaldır** butonları.
- **Kur:** `~/.claude/settings.json` okunur, mevcut hook'lar korunarak ljaspNotch'un girdileri eklenir, değişiklik **diff olarak gösterilir**, kullanıcı onaylarsa önce `settings.json.bak-YYYYMMDD-HHMMSS` yedeği alınır, sonra dosya atomik olarak yazılır.
- **Kaldır:** Yalnızca ljaspNotch'un eklediği girdiler (URL'si `/claude/hook` ile biten ve portu eşleşen) silinir.
- Token header'a düz metin olarak yazılır. Gerekçe: masaüstü uygulamalar kabuk ortam değişkenlerini (`.zshrc`) devralmaz, `$VAR` kullanılırsa Claude masaüstü uygulamasında hook'lar sessizce başarısız olur.
- Ayarlarda `allowedHttpHookUrls` tanımlıysa ve ljaspNotch'un adresini içermiyorsa kullanıcı uyarılır.
- Elle kurmak isteyenler için `docs/claude-code-setup.md` aynı yapılandırmayı anlatır.

### Örnek yapılandırma
```json
{
  "hooks": {
    "UserPromptSubmit":  [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 5,   "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }],
    "PermissionRequest": [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 300, "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }],
    "Notification":      [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 5,   "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }],
    "Stop":              [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 5,   "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }],
    "StopFailure":       [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 5,   "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }],
    "SessionEnd":        [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 2,   "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }]
  }
}
```
Tüm olaylar tek endpoint'e gelir; sunucu `hook_event_name` alanına göre dağıtır.

## 10. Tema sistemi

### Alanlar
| Alan | Tip | Açıklama |
|---|---|---|
| `id`, `name` | string | Tema kimliği ve görünen adı |
| `material` | `glass` / `solid` / `tinted` | Liquid Glass (`.glassEffect()`), donanım notch'uyla kaynaşan düz siyah, renkli cam |
| `tint` | hex | `tinted` için cam rengi |
| `background`, `foreground`, `secondary`, `accent` | hex | Renkler |
| `cornerRadius` | sayı | Açık panelin köşe yuvarlaklığı |
| `expandedSize` | `{width, height}` | Açık panel boyutu (F2) |
| `peekExtraWidth` | sayı | `peek` durumunda notch'un iki yanına eklenen genişlik |
| `animation` | `{response, damping}` | SwiftUI spring parametreleri |
| `fontDesign` | `default` / `rounded` / `monospaced` / `serif` | Yazı tipi stili |
| `shadow` | bool | Açık panel gölgesi |

### Örnek
```json
{
  "id": "midnight",
  "name": "Midnight",
  "material": "tinted",
  "tint": "#1E3A8A",
  "background": "#000000",
  "foreground": "#FFFFFF",
  "secondary": "#9CA3AF",
  "accent": "#3B82F6",
  "cornerRadius": 22,
  "expandedSize": { "width": 640, "height": 190 },
  "peekExtraWidth": 70,
  "animation": { "response": 0.42, "damping": 0.82 },
  "fontDesign": "rounded",
  "shadow": true
}
```

### Kurallar
- Hazır temalar: **Classic** (solid), **Glass** (glass), **Midnight** (tinted). Uygulama paketinde gelir, değiştirilemez; kopyalanıp düzenlenebilir.
- Kullanıcı temaları: `~/Library/Application Support/ljaspNotch/Themes/*.json`. İçe/dışa aktarma Ayarlar'dan.
- Decode toleranslı: bilinmeyen alan yok sayılır, eksik alan varsayılan değeri alır. Böylece eski temalar yeni sürümlerde bozulmaz.
- Ayarlardaki her değişiklik panelde **canlı önizlenir**.

## 11. Fazlar ve kabul kriterleri

Her faz sonunda: derleme temiz, testler yeşil, kabul kriterleri kontrol edildi, kullanıcıya manuel test listesi verildi, kullanıcı onayladı. Ardından faz dalı PR ile `main`'e alınır ve kullanıcı onayıyla `v0.N.0` ön sürümü yayınlanır (Faz 1'den itibaren). Böylece geliştirme sürerken de indirilebilir sürümler olur.

### Faz 0: İskelet ve repo hijyeni
- `project.yml`, `Local.xcconfig.example`, `.editorconfig`, `.swift-format`. (README, LICENSE, `.gitignore`, CLAUDE.md ve bu belge ilk commit'te repoda zaten var.)
- README.tr, CONTRIBUTING, CHANGELOG, SECURITY, CODE_OF_CONDUCT, PR ve issue şablonları.
- `LSUIElement` (Dock ikonu yok), menü çubuğu simgesi (Ayarlar / Duraklat / Çık), boş Ayarlar penceresi, girişte başlat (`SMAppService.mainApp`).
- `os.Logger` altyapısı, sürüm numarasının tek yerden yönetimi (`MARKETING_VERSION`).
- GitHub Actions: `build.yml` ve `release.yml` (§ 14). Release iş akışı bir test etiketiyle (`v0.0.1-test`) denenir, sonra etiket ve taslak release kullanıcı onayıyla silinir.
- Kullanıcı onayıyla repo ayarları (`gh repo edit`): açıklama, konular (`macos`, `notch`, `swiftui`, `claude-code`, `youtube-music`).
- **Kabul:** Temiz klondan `xcodegen generate && xcodebuild` geçer. Dock'ta ikon yok. Menü çubuğu simgesi çalışır. CI yeşil. Release iş akışı indirilebilir bir zip üretiyor.

### Faz 1: Notch penceresi
- `NotchGeometry`, `NotchPanel`, `NotchWindowController`, `NotchViewModel`, hover takibi, açılma/kapanma animasyonu, tıklama geçişi, ekran/uyku olayları.
- **Kabul:** Hover ile açılır ve kapanır. 100 kez aç/kapa sonrası donma yok. Panel kapalıyken menü çubuğu öğeleri tıklanabilir. Uyku/uyanma ve harici monitör tak/çıkar sonrası doğru konum. Tam ekran uygulamada gizlenir. Boşta CPU < %1.

### Faz 2: Tema ve ayarlar
- `Theme`, `ThemeStore`, üç hazır tema, Ayarlar'da görünüm sekmesi (boyut, materyal, renk, animasyon, gecikmeler) ve canlı önizleme, içe/dışa aktarma.
- **Kabul:** Tema ve boyut değişikliği anında uygulanır, yeniden başlatınca korunur. Bozuk bir tema dosyası uygulamayı çökertmez.

### Faz 3: Widget altyapısı ve ilk widget'lar
- `NotchWidget`, `WidgetRegistry`, `LayoutStore`, sekmeler, `LiveActivityCenter`. Widget'lar: Calendar, Battery, Timer.
- **Kabul:** Widget'lar Ayarlar'dan eklenir, kaldırılır, sıralanır. Takvim izni istenirken panel donmaz. Zamanlayıcı bitince `peek` canlı etkinliği görünür.

### Faz 4: Spotify ve Apple Music
- `MediaProvider`, `MediaCoordinator`, `SpotifyProvider`, `AppleMusicProvider`, Media widget'ı ve medya canlı etkinliği (kapak + ses dalgası animasyonu).
- **Kabul:** Kapalı müzik uygulaması asla başlatılmaz. Şarkı değişimi 1 sn içinde yansır. Oynat/durdur/ileri/geri/sarma çalışır. Otomasyon izni reddedilirse anlaşılır bir mesaj gösterilir.

### Faz 5: YouTube / YouTube Music
- `LocalServer` (FlyingFox, WebSocket), token yönetimi, `BrowserProvider`, Chrome eklentisi (`extensions/chrome`), eklenti kurulum anlatımı.
- **Kabul:** YouTube Music ve YouTube'da çalan içerik notch'ta görünür, kontroller çalışır. Birden fazla sekmede doğru sekme seçilir. Uygulama yeniden başlayınca eklenti kendiliğinden yeniden bağlanır. Token'sız bağlantı reddedilir.

### Faz 6: Claude Code
- `/claude/hook` endpoint'i, `ClaudeCodeService`, `PermissionBroker`, Claude Code widget'ı (oturum listesi) ve izin canlı etkinliği, `HookInstaller`, `docs/claude-code-setup.md`.
- **İlk iş:** § 16'daki 1. ve 2. maddeyi gerçek bir oturumla doğrula, bulguları bu belgeye yaz.
- **Kabul:** İzin isteği notch'ta görünür; onay, ret ve "terminalde yanıtla" çalışır. Uygulama kapalıyken Claude Code normal çalışır. İş bitince ve hata olunca kısa bildirim gelir. Kurulum yardımcısı diff gösterir, yedek alır, kaldırınca yalnızca kendi girdilerini siler.

### Faz 7: Ek widget'lar
- Tray, Mirror, Weather, Shortcuts, System Stats.
- **Kabul:** Her widget yalnızca panel açıkken kaynak kullanır (kamera, örnekleme). Dışarı istek atan widget'lar README gizlilik bölümüne eklendi.

### Faz 8: Cilalama ve v1.0
- Instruments ile performans profili (N1), VoiceOver etiketleri (N5), Türkçe çevirinin tamlığı, README ekran görüntüleri/GIF, özgün uygulama ikonu.
- Ayarlar'da "Güncellemeleri kontrol et" (§ 14) ve "Tanılama bilgisini kopyala".
- CHANGELOG ve `v1.0.0` sürümü.
- **Kabul:** Tüm N maddeleri sağlanıyor. README'deki indirme ve kaynaktan kurulum adımları temiz bir Mac'te baştan sona çalışıyor.

### Faz 9: Opsiyonel
- Video önizleme (§ 8, deneysel), Lyrics widget'ı, AirPods araştırması, Jira widget'ı, Safari eklentisi.

## 12. Lokal sunucu, güvenlik ve gizlilik
- Sunucu yalnızca `127.0.0.1` adresini dinler. Varsayılan port `47823`, Ayarlar'dan değiştirilebilir. Port doluysa kullanıcıya açık bir hata gösterilir.
- Token: ilk açılışta 32 bayt rastgele üretilir, **Keychain**'de saklanır. Ayarlar'da göster / kopyala / yenile. Yenilenince hook yapılandırmasının güncellenmesi gerektiği söylenir.
- HTTP: `X-LjaspNotch-Token` header'ı zorunlu, yanlışsa 401. CORS header'ı dönülmez; böylece web sayfalarından gelen JSON istekleri tarayıcıda takılır.
- WebSocket: el sıkışmada `Origin` bir `chrome-extension://` adresi olmalı, ilk mesaj geçerli token içeren `hello` olmalı. Aksi halde bağlantı kapatılır.
- Telemetri yok. Dışarı giden istekler yalnızca kullanıcının açtığı özelliklerden gelir (kapak görselleri, Open-Meteo, LRCLIB, GitHub Releases güncelleme kontrolü) ve README'de listelenir. Güncelleme kontrolü Ayarlar'dan kapatılabilir.
- Claude Code verileri (komutlar, dosya yolları, mesajlar) yalnızca bellekte tutulur. Gerçek payload'ları kaydeden bir hata ayıklama modu olabilir; varsayılan kapalıdır ve açıkken Ayarlar'da uyarı gösterilir.

## 13. İzinler, Info.plist ve entitlement'lar
| İhtiyaç | Info.plist / entitlement | Ne zaman istenir |
|---|---|---|
| Dock'ta görünmeme | `LSUIElement = YES` | |
| Spotify / Apple Music kontrolü | `NSAppleEventsUsageDescription` + `com.apple.security.automation.apple-events` | Media widget'ı ilk kez açılınca, Ayarlar üzerinden |
| Takvim | `NSCalendarsFullAccessUsageDescription` | Calendar widget'ı eklenince, Ayarlar üzerinden |
| Kamera (Mirror) | `NSCameraUsageDescription` + `com.apple.security.device.camera` | Mirror widget'ı eklenince |
| Ekran Kaydı | (sistem kendisi sorar) | Yalnızca deneysel video önizleme açılırsa |
| Erişilebilirlik | Gerekmez | Gerekirse önce kullanıcıya sorulur |

App Sandbox kapalı, Hardened Runtime açık. Tüm izin istekleri kullanıcının bir eylemiyle ve panel kapalıyken tetiklenir.

## 14. Açık kaynak ve dağıtım
- **Lisans:** MIT. Bağımlılık: FlyingFox (MIT).
- **Kod kopyalama yok:** Boring Notch (GPL) ve NotchNook (kapalı kaynak) kodu alınmaz; fikir ve UX ilhamı serbesttir. README'de "inspired by" ifadesi kullanılabilir ama "NotchNook" adı ürün adında, ikonda veya arayüzde geçmez.
- **İmzalama:** Katkıcılar kendi ücretsiz Personal Team'leriyle `Local.xcconfig` üzerinden derler.
- **Sürümleme:** SemVer. Etiket `vX.Y.Z` → `MARKETING_VERSION`; build numarası CI çalışma numarası. Faz N sonu `v0.N.0`, Faz 8 sonu `v1.0.0`.
- **Release iş akışı (`release.yml`, `v*` etiketiyle tetiklenir):**
  1. Xcode 26 içeren macOS runner'da `xcodegen generate` + Release derlemesi.
  2. Uygulamaya **ad-hoc imza** (`codesign --force --deep --sign -`). Apple Silicon'da hiç imzası olmayan uygulama çalışmaz; ad-hoc imza yeterli.
  3. `ljaspNotch-vX.Y.Z.zip` (uygulama) ve `ljaspNotch-chrome-extension-vX.Y.Z.zip` (eklenti) üretilir, SHA-256 değerleri hesaplanır.
  4. GitHub Release oluşturulur: notlar CHANGELOG'dan, `v0.x` sürümleri "pre-release" işaretli, dosyalar ve SHA-256 değerleri eklenir.
- **Kullanıcının indirip açması:** Uygulama Developer ID ile imzalı ve notarize edilmiş olmadığı için Gatekeeper uyarı verir. README iki yol anlatır: Sistem Ayarları → Gizlilik ve Güvenlik → "Yine de Aç", ya da `xattr -dr com.apple.quarantine /Applications/ljaspNotch.app`. Ad-hoc imzalı sürümlerde macOS izinleri (otomasyon, takvim) güncellemeden sonra yeniden isteyebilir; README'de belirtilir.
- **Notarization (ileride):** Developer ID imzası ve notarization ücretli Apple Developer Program üyeliği gerektirir. Üyelik alınırsa release iş akışına eklenir, ardından Homebrew cask değerlendirilir.
- **Güncelleme kontrolü (v1.0):** Uygulama açılışta ve günde bir kez GitHub Releases API'sinden son sürümü sorgular, yeni sürüm varsa menü çubuğunda ve Ayarlar'da bildirir, indirme sayfasını açar. Otomatik indirme/kurulum yok (Sparkle notarization sonrası değerlendirilir). Ön sürümleri dahil etme ayarı vardır.
- **CI (`build.yml`):** Her push ve PR'da `xcodegen generate` → derleme → test, imzasız (`CODE_SIGNING_ALLOWED=NO`). PR'lar CI yeşil olmadan merge edilmez.
- **README içeriği:** Özellikler, ekran görüntüleri/GIF, gereksinimler, kaynaktan kurulum, Chrome eklentisi kurulumu, Claude Code entegrasyonu, gizlilik, katkı, lisans.
- **CONTRIBUTING:** Kurulum adımları, kod stili (2 boşluk, swift-format), dal ve commit formatı, PR kontrol listesi (derleme, test, Türkçe çeviri, README gizlilik bölümü, CHANGELOG).
- **SECURITY.md:** Lokal sunucu ve hook entegrasyonu nedeniyle güvenlik açıkları herkese açık issue yerine GitHub'ın özel güvenlik bildirimi (Security Advisories) ile bildirilir.
- **Issue şablonları:** Hata bildiriminde macOS sürümü, Mac modeli, uygulama sürümü ve "Tanılama bilgisini kopyala" çıktısı istenir. Claude Code payload'larının, kişisel dosya yollarının ve token'ların paylaşılmaması uyarısı bulunur.
- **Tanılama bilgisi:** Ayarlar'daki buton yalnızca uygulama/macOS sürümü, Mac modeli, ekran ve notch ölçüleri, izin durumları ve etkin widget listesini kopyalar. Kişisel veri, token veya Claude Code içeriği içermez.

## 15. Test stratejisi
- **Birim testleri:** `NotchGeometry` hesapları, `NotchViewModel` durum geçişleri, `Theme` decode toleransı, `MediaCoordinator` öncelik kuralları, hook payload decode (fixture'larla), `PermissionBroker` zaman aşımı ve kuyruk davranışı, `HookInstaller` birleştirme/kaldırma mantığı (geçici dizinde, gerçek `~/.claude` dosyasına dokunmadan).
- **Fixture'lar:** `ljaspNotchTests/Fixtures/claude/*.json`. Gerçek payload'lardan üretilir, kişisel yollar ve içerik temizlenir.
- **Manuel testler:** Her fazın sonunda Claude Code kullanıcıya adım adım bir liste verir.

## 16. Doğrulanacaklar
1. `PermissionRequest` hook'u cevap beklerken terminaldeki izin diyaloğu da görünüyor mu, yoksa hook bitene kadar bekliyor mu? Sonuca göre "Terminalde yanıtla" davranışı ve timeout süresi kesinleşir.
2. `Notification` ve `Stop` olaylarının gerçek payload alanları (gerçek oturumdan loglanır, fixture olarak kaydedilir).
3. Spotify ve Apple Music dağıtık bildirimlerinin macOS 26'daki `userInfo` alanları.
4. Panel seviyesinin menü çubuğunun ve tam ekran Space'lerin üstünde doğru davranması.
5. YouTube `<video>` karesinin canvas'a çizilip okunabilmesi (deneysel video önizleme için).
6. Hook'ların Claude masaüstü uygulamasındaki Code oturumlarında `~/.claude/settings.json` üzerinden tetiklendiği.
