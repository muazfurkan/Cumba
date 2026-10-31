# Manuel test listesi (v1.0.0)

Otomatik testlerin ve CI'ın kapsayamadığı, gerçek donanım, izin pencereleri ya da gerçek uygulamalar gerektiren kontroller. Her maddede ne yapılacağı ve ne görülmesi gerektiği yazılı.

**Hazırlık:** NotchNook'u kapatın. Son sürümü [Releases](https://github.com/muazfurkan/ljaspNotch/releases) sayfasından indirip Uygulamalar'a taşıyın (ya da kaynaktan derleyin) ve açın.

## Notch paneli
1. İmleci notch'un üstünde tutun: panel, kısa bir gecikmeyle notch'tan büyüyerek açılmalı. İçerik, şekil açıldıktan sonra hafif bulanıklıktan netleşerek belirmeli; "patlama" veya sekme olmamalı.
2. İmleci notch'un üstünden hızla geçirin: panel açılmamalı.
3. Notch'a tıklayın: panel beklemeden açılmalı. Trackpad'de hafif bir tık hissedilmeli (Ayarlar > Genel'den kapatılabilir).
4. Raptiyeye basın: panel imleç uzaklaşınca da açık kalmalı. Tekrar basınca kapanabilmeli.
5. Panel kapalıyken notch'un yanındaki menü öğelerine tıklayın: normal çalışmalı.
6. Bir uygulamayı tam ekran yapın: panel açılmamalı. Tam ekrandan çıkınca yeniden çalışmalı.
7. Kapağı kapatıp açın, harici monitörü takıp çıkarın: panel doğru yerde olmalı.

## Görünüm (Ayarlar > Görünüm)
8. Bu sekme açıkken panel açık kalmalı. Classic, Glass ve Midnight temalarını sırayla seçin: renk, materyal ve köşe değişikliği anında görünmeli.
9. Temayı çoğaltın, genişlik/yükseklik/köşe ayarlarıyla oynayın: panel canlı değişmeli. Uygulamayı yeniden başlatınca ayarlar korunmalı.

## Widget'lar (Ayarlar > Widget'lar)
10. Bir sekme ekleyin, adını ve simgesini değiştirin, widget ekleyin, kaldırın, sıralayın: panel buna göre değişmeli.
11. Takvim > "Takvim Erişimine İzin Ver": izin penceresi panelin arkasında kalmamalı. İzin verince bugünün ve yarının etkinlikleri görünmeli.
12. Zamanlayıcı: 5 dk başlatın ve paneli kapatın. Notch'un yanında geri sayım görünmeli; bitince ses çalmalı ve "Bitti" göstergesi çıkmalı.
13. Pil: şarj kablosunu takın, notch'un yanında kısa bir şimşek göstergesi çıkmalı.
14. Raf: Finder'dan bir dosyayı notch'a sürükleyip bekleyin. Panel açılınca dosyayı Raf'a bırakın; dosya görünmeli, dışarı sürüklenebilmeli, AirDrop menüsü açılmalı.
15. Ayna: Ayarlar'dan kamera izni verin. Ayna yalnızca panel açıkken çalışmalı (yeşil kamera ışığı panel kapanınca sönmeli).
16. Hava durumu: Ayarlar'dan bir şehir arayıp seçin. Sıcaklık ve simge görünmeli.
17. Kısayollar: Ayarlar'dan birkaç kısayol seçin, panelden çalıştırın.
18. Sistem: CPU ve bellek grafiği yalnızca panel açıkken akmalı.

## Medya
19. Spotify'ı açın, Ayarlar > Widget'lar > Medya > Spotify > "İzin Ver". Bir şarkı çalın: kapak, başlık ve ilerleme görünmeli; kartın arkasında kapak renginde bir ışıltı olmalı. Notch'un yanında ses dalgası görünmeli.
20. Oynat/duraklat, ileri, geri ve ilerleme çubuğuna tıklayarak sarma çalışmalı. Şarkı değişimi 1 sn içinde yansımalı.
21. Aynısını Müzik uygulamasıyla yapın. Spotify ve Müzik kapalıyken ljaspNotch onları asla açmamalı.
22. İzni Sistem Ayarları > Gizlilik ve Güvenlik > Otomasyon'dan kapatın: widget'ta anlaşılır bir uyarı çıkmalı.

## YouTube (Chrome eklentisi)
23. Ayarlar > Bağlantılar'da "YouTube eklentisini bağla"yı açın: sunucu "çalışıyor" görünmeli (kapalıyken hiçbir port dinlenmemeli). Token'ı "Kopyala" ile alın (bir dakika sonra panodan kendiliğinden silinir). "Eklenti Klasörünü Göster" ile klasörü bulun, Chrome'da "Paketlenmemiş öğe yükle" ile ekleyin, seçeneklere port ve token'ı yapıştırın: durum "Uygulamaya bağlı" olmalı.
24. YouTube Music'te ve YouTube'da bir şey çalın: notch'ta görünmeli, kontroller ve sarma çalışmalı. İki sekmede çalınca en son başlayan gösterilmeli.
25. ljaspNotch'u kapatıp açın: eklenti birkaç saniye içinde kendiliğinden yeniden bağlanmalı.

## Claude Code
26. Ayarlar > Claude Code > "Kur…": değişiklik farkı (diff) gösterilmeli, token `••••••••` olarak maskelenmeli. Dosyanız farklı biçimdeyse "yeniden biçimlenecek" notu görünmeli. Kaydedince `~/.claude` içinde `settings.json.bak-…` yedeği oluşmalı. "Soket" satırı "Dinliyor" göstermeli (hook'lar kurulu değilken "Durdu").
27. Terminalde Claude Code'da izin isteyen bir komut çalıştırın: notch'un yanında el simgesi çıkmalı. Panelde komutun tamamı görünmeli; düğmeler kart çıktıktan kısa süre sonra etkinleşmeli. İzin Ver / Reddet / Terminalde çalışmalı. Ayrıca terminalde izin diyaloğunun aynı anda görünüp görünmediğini not edin (SPEC § 16-1).
28. İş bitince "Bitti", hata olunca "Hata" göstergesi kısa süre görünmeli.
29. ljaspNotch kapalıyken Claude Code normal çalışmalı (izni terminal sormalı).
30. Claude masaüstü uygulamasındaki Code oturumunda da 27. maddeyi deneyin (SPEC § 16-6).
31. "Kaldır…": yalnızca ljaspNotch girdileri silinmeli, diğer hook'larınız kalmalı; "Soket" satırı "Durdu"ya dönmeli.
31a. "Notch'tan izin ver" = "Kabuk komutları dışında hepsi": Bash isteğinde İzin Ver düğmesi olmamalı, kartta "kapalı" notu görünmeli; Edit gibi bir istekte İzin Ver görünmeli. "Hiçbiri"nde hiçbir istekte İzin Ver olmamalı.

## Genel
32. Ayarlar > Genel > "Şimdi Denetle": güncel sürümde "ljaspNotch güncel." yazmalı.
33. "Tanılama Bilgisini Kopyala": panodaki metinde token, dosya yolu veya kişisel veri olmamalı.
34. Sistem dilini Türkçe/İngilizce yapın: tüm metinler çevrilmiş olmalı.
35. VoiceOver'ı açın (⌘F5): panel düğmeleri anlamlı adlarla okunmalı.
36. `defaults delete io.github.muazfurkan.ljaspnotch hasSeenWelcome` sonrası uygulamayı açın: karşılama penceresi bir kez görünmeli; Uygulamalar dışından açıldıysa sarı taşıma uyarısı olmalı.
37. Sistem Ayarları > Erişilebilirlik > Ekran > "Hareketi azalt" açıkken panel yaylanmadan açılıp kapanmalı.
38. Yeni bir sürümün `.dmg` dosyasını indirin: `shasum -a 256` değeri `SHA256SUMS.txt` ile, `gh attestation verify` başarılı olmalı; disk görüntüsünde Uygulamalar kısayolu olmalı.
