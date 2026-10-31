# ljaspNotch: kişisel notch uygulaması

MacBook notch'unu genişleyen bir panele çeviren, tema ve widget'larla özelleştirilebilir bir macOS uygulaması. GitHub'da **açık kaynak (MIT)** olarak yayınlanacak. Geliştiricinin cihazı M5 MacBook Pro / macOS 26; kod başka notch'lu Mac'lerde de çalışacak şekilde genel yazılır. App Store'a gönderilmeyecek.

Detaylı gereksinimler, mimari ve fazlar: `docs/SPEC.md`. Her faza başlamadan önce SPEC'in ilgili bölümünü oku.

## İletişim
- Kullanıcıyla **Türkçe** konuş. Cevaplar kısa olsun, gereksiz açıklama yapma.
- Bir değişiklikten sonra sadece **değişen/eklenen dosyaları** (yollarıyla) ve 1-3 cümlelik özeti ver.
- Kullanıcı Swift'te yeni. Kritik bir kararı (mimari, bağımlılık, izin) 1-2 cümleyle gerekçelendir.

## Çalışma şekli
1. Fazlar `docs/SPEC.md` § 11'deki sırayla ilerler. Bir faza başlarken kısa bir plan (madde madde) yaz ve **kullanıcı onayı al**.
2. Faz içinde küçük adımlarla ilerle; her adımdan sonra projeyi derle. Derlenmeyen kodla adımı bitirme.
3. Faz sonunda SPEC'teki kabul kriterlerini kontrol et ve kullanıcıya **manuel test listesi** ver (neye tıklayacak, ne görmeli).
4. Kullanıcı onaylamadan bir sonraki faza geçme.
5. SPEC ile çelişen ya da SPEC'te olmayan bir karar gerekirse önce sor. Karar netleşince SPEC'i güncelle.

## Komutlar
```bash
# İlk kurulum (bir kere)
brew install xcodegen xcbeautify gh
gh auth login

# Xcode projesini project.yml'den üret (project.yml değişince tekrar çalıştır)
xcodegen generate

# Derle
set -o pipefail && xcodebuild -project ljaspNotch.xcodeproj -scheme ljaspNotch -configuration Debug -derivedDataPath build build | xcbeautify

# Çalıştır (önce eskisini kapat)
pkill -x ljaspNotch; open build/Build/Products/Debug/ljaspNotch.app

# Testler
xcodebuild -project ljaspNotch.xcodeproj -scheme ljaspNotch -derivedDataPath build test

# Logları izle
log stream --predicate 'subsystem == "io.github.muazfurkan.ljaspnotch"' --level debug
```
`xcbeautify` yoksa pipe'ı kaldır ya da `brew install xcbeautify` öner. `.xcodeproj` dosyasını **asla elle düzenleme**; her şey `project.yml` üzerinden.

## Git ve GitHub
Repo: https://github.com/muazfurkan/ljaspNotch (public, MIT). Varsayılan dal `main`; `main` her zaman derlenen ve çalışan haldedir, çünkü kullanıcılar oradan indirir.

- Her faz kendi dalında yürür: `faz-<N>-<kisa-ad>` (örn. `faz-1-notch-window`). Faz başında dalı `main`'den aç.
- Derlenen ve testleri geçen **her adımdan sonra** commit at ve dalı hemen push'la (`git push -u origin <dal>`). Derlenmeyen kod commit'lenmez.
- Commit öncesi `git status` ve `git diff --staged` ile kontrol et: sır, kişisel yol, `Local.xcconfig`, `build/` veya üretilen `.xcodeproj` girmemeli.
- Faz bitince `gh pr create` ile `main`'e PR aç (başlık ve açıklama İngilizce, kabul kriterlerinin listesiyle). Merge **kullanıcı onayıyla**, squash merge.
- Merge sonrası kullanıcı onayıyla ön sürüm etiketi at: Faz N → `v0.N.0` (`git tag v0.N.0 && git push origin v0.N.0`). Etiket, release iş akışını tetikler (SPEC § 14). v1.0.0 Faz 8 sonunda.
- `CHANGELOG.md` her PR'da güncellenir ("Unreleased" bölümü).
- `main`'e doğrudan push, force push, geçmişi yeniden yazma, dal veya etiket silme: **yalnızca kullanıcının açık onayıyla**.

## Teknoloji
- Swift 6 (strict concurrency açık), SwiftUI + AppKit. Deployment target: **macOS 26.0**.
- Proje: XcodeGen (`project.yml`). Bağımlılıklar Swift Package Manager ile.
- İzin verilen bağımlılık: yalnızca lokal HTTP/WebSocket sunucusu için **FlyingFox**. Başka paket eklemeden önce sor. Paket sürümleri `project.yml`'de `exactVersion` ile sabitlenir (üretilen proje repoda olmadığı için `Package.resolved` da yok).
- App Sandbox **kapalı**, Hardened Runtime **açık** (gerekçe: AppleScript otomasyonu + lokal sunucu).
- İmzalama: Apple Development + kullanıcının ücretsiz Personal Team'i. `DEVELOPMENT_TEAM` repoya girmez, `Local.xcconfig` içinde durur (gitignore). Ad-hoc imza kullanma; her derlemede izinler sıfırlanır.

## Kod kuralları
- **Girinti: 2 boşluk** (Swift varsayılanı 4'tür; burada 2 kullan). `.editorconfig` ve swift-format ayarı bunu zorlar.
- Tanımlayıcılar ve kod yorumları **İngilizce** (açık kaynak katkıcılar için). Yorumlar kısa ve sade olsun; kodu kullanıcıya sohbette Türkçe açıkla.
- Arayüz metinleri `Localizable.xcstrings` (String Catalog) üzerinden. Geliştirme dili İngilizce, **Türkçe çevirisi her zaman eksiksiz**. Kod içinde düz string olarak arayüz metni yazma.
- Force unwrap (`!`) ve `try!` yok. Hataları `os.Logger` ile logla (subsystem `io.github.muazfurkan.ljaspnotch`, kategori modül adı).
- Bir dosya ~300 satırı geçiyorsa böl.
- UI kodu `@MainActor`. I/O, AppleScript, ağ ve dosya işleri asla ana thread'de çalışmaz.
- Zamanlayıcıyla sürekli yoklama (polling) yerine olay tabanlı çalış: dağıtık bildirimler, NotificationCenter, WebSocket mesajları. Yoklama şartsa en az 1 sn aralık ve sadece panel görünürken.

## Kesin yasaklar
- `~/.claude/settings.json` dosyasını kullanıcının açık onayı olmadan **değiştirme**. Değiştirirken önce yedek al, değişikliği diff olarak göster.
- Private framework / özel API kullanma. Zorunlu görünüyorsa önce sor.
- Sistem ayarlarını değiştiren kod yazma.
- Lokal sunucu yalnızca `127.0.0.1` adresini dinler, token olmadan istek kabul etmez.

## Açık kaynak kuralları
- Repoya **asla sır veya kişisel veri girmez**: token, `DEVELOPMENT_TEAM`, kişisel dosya yolları, e-posta, API anahtarı. `Local.xcconfig`, `build/` ve üretilen `ljaspNotch.xcodeproj` gitignore'dadır.
- Kişiye özel her şey (hava durumu konumu, Jira adresi, port vb.) koda gömülmez, Ayarlar'dan girilir.
- Başka projelerden **kod kopyalanmaz**. Özellikle Boring Notch (GPL lisanslı) ve NotchNook (kapalı kaynak). Fikir alınabilir, kod alınmaz. Yeni bağımlılığın lisansı MIT ile uyumlu olmalı.
- Uygulama **telemetri göndermez**. Dışarıya istek atan her özellik (hava durumu, şarkı sözleri, kapak görselleri) README'deki gizlilik bölümünde listelenir.
- "NotchNook" adı arayüzde, ikonda ve markada kullanılmaz.
- Commit mesajları İngilizce ve Conventional Commits formatında (`feat:`, `fix:`, `docs:`, `refactor:`). README İngilizce, `README.tr.md` Türkçe.

## Bilinen tuzaklar (bunlara dikkat)
- **AppleScript uygulamayı başlatır:** `tell application "Spotify"` Spotify kapalıysa onu açar. Komut göndermeden önce `NSRunningApplication` ile çalışıp çalışmadığını kontrol et.
- **NSAppleScript thread-safe değil:** Tek bir actor/serial queue üzerinden çalıştır, ana thread'de asla.
- **İzin pencereleri panelin arkasında kalabilir:** Bu, NotchNook'un takvimde donma sebebine benziyor. İzin isteklerini Ayarlar penceresinden tetikle; panel açıkken tetiklenecekse önce paneli kapat ve uygulamayı aktive et.
- **Tıklamaların menü çubuğuna geçmesi:** Panel kapalıyken yalnızca notch alanı fare olaylarını yakalar; geri kalanı `ignoresMouseEvents` ile alttaki menü çubuğuna geçer.
- **Ekran değişiklikleri:** Harici monitör, çözünürlük değişimi ve uyku/uyanma sonrası pencere konumunu yeniden hesapla.
- **Claude Code hook'ları:** Hiçbir hook'ta `onFailure: "block"` kullanma. Uygulama kapalıyken Claude Code normal akışına devam etmeli.
