# Notchy Proje Dosya Yapısı

Bu belge, Notchy projesindeki dosyaların ne işe yaradığını açıklamaktadır.

## Ana Uygulama Dosyaları

- **BotdockApp.swift**: Uygulamanın SwiftUI giriş noktasıdır. Uygulama döngüsünü başlatır ve ana pencereleri yapılandırır.
- **AppDelegate.swift**: Standart macOS uygulama delegesidir. Menü çubuğu ikonunu yönetir, uygulama başlangıcındaki kurulumları yapar ve pencere yönetimini kontrol eder.
- **NotchWindow.swift**: MacBook çentiğinde (notch) görünen "pill" (hap) şeklindeki arayüzün mantığını ve görünümünü yönetir. Fare ile üzerine gelindiğinde veya tıklandığında terminal panelinin açılmasını tetikler.

## Terminal ve Oturum Yönetimi

- **TerminalPanel.swift**: Çentik altından açılan ana terminal penceresini tanımlar.
- **PanelContentView.swift**: Terminal panelinin içindeki ana görünümü (header, tablar ve terminal alanı) düzenler.
- **TerminalSession.swift**: Tek bir terminal oturumunun verilerini ve durumunu temsil eden modeldir.
- **TerminalSessionView.swift**: Bir terminal oturumunun içeriğini ve terminal ekranını (SwiftTerm kullanarak) görselleştirir.
- **SessionStore.swift**: Aktif tüm terminal oturumlarını yöneten, yeni oturum açan veya kapatan ana depodur.
- **SessionTabBar.swift**: Farklı oturumlar arasında geçiş yapmayı sağlayan, üst kısımdaki sekme çubuğudur.
- **TerminalManager.swift**: Terminal süreçlerinin (pty) başlatılması, veri alışverişi ve komut gönderilmesi gibi düşük seviyeli terminal işlemlerini yönetir.

## Yardımcı ve Mantıksal Dosyalar

- **SettingsManager.swift**: Uygulama ayarlarını (kısayollar, görünüm tercihleri vb.) kaydetmek ve okumak için kullanılır.
- **SettingsWindow.swift**: Kullanıcının uygulama ayarlarını değiştirebileceği ayarlar penceresinin arayüzüdür.
- **XcodeDetector.swift**: Mac üzerinde o an açık olan Xcode projelerini tespit eder, böylece terminal otomatik olarak ilgili proje dizininde açılabilir.
- **CheckpointManager.swift**: Git tabanlı "checkpoint" (kontrol noktası) sistemini yönetir. Cmd+S ile projenin o anki durumunun yedeğini almayı sağlar.
- **BotFaceView.swift**: Çentik (notch) içinde görünen Claude'un "yüzü" veya animasyonlu durum göstergesidir.

## Kaynaklar ve Yapılandırma

- **Assets.xcassets**: Uygulama ikonları, renk paletleri ve görsellerin bulunduğu klasördür.
- **Sounds/**: Uygulama içindeki bildirim ve durum seslerini (görev tamamlandı, girdi bekleniyor vb.) içerir.
- **Notchy.entitlements**: macOS için gerekli yetkilendirme ve güvenlik izinlerini tanımlar.

## Dökümantasyon

- **README.md**: Projenin genel tanıtımı, özellikleri ve kurulum talimatları.
- **TODO.md**: Yapılacak işler listesi.
- **NOTCH_DESIGN.md**: Çentik tasarımı ve animasyon mantığı üzerine notlar.
- **MEMORY.md**: Önemli mimari kararların veya geçmiş hataların kaydedildiği dosya.
- **CLAUDE.md**: Claude Code kullanımıyla ilgili özel talimatlar ve ipuçları.
