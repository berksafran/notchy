# Notchy Development TODO

## Unresolved UI & UX Issues
- [x] **Icon Update Bug:** Hover ikonları `apple.terminal` ve `gear` olarak güncellendi. `@Observable` singleton pattern ile reaktivite sorunu çözüldü.
- [ ] **Settings Toggle Rendering:** Ayarlar sayfasındaki Switch (Toggle) bileşenleri ilk açılışta tamamen mavi/bozuk görünüyor. macOS native Switch stiliyle ilgili bir hizalama veya renk çakışması mevcut.
- [ ] **Container Gap:** Fiziksel çentik ile açılan panel (container) arasında hala çok ince bir boşluk veya uyumsuzluk olabilir. `hoverGrowY` ve `finalY` değerlerinin tekrar kalibre edilmesi gerekiyor.
- [ ] **Layout Consistency:** Terminal ve Settings layoutları ayrıldı ancak aralarındaki geçişlerin pürüzsüzlüğü ve arka plan bütünlüğü (Solid Black vs Glassmorphism) tekrar gözden geçirilmeli.

## Security & Permissions
- [ ] **"rg" (ripgrep) Warning:** macOS'in `rg` aracını malware olarak görüp engellemesi sorunu. `xattr` veya Gatekeeper üzerinden kalıcı izin verilmesi gerekiyor.
- [ ] **File Access Permissions:** Geliştirme aşamasında her `Cmd+R` sonrası çıkan "File Access" uyarılarını minimize edecek bir yöntem (Full Disk Access rehberi veya Sandbox ayarı) bulunmalı.

## Layout Redesign
- [ ] **Unified Notch Container:** Notch window genişliği ile panel container genişliği birleştirilecek — tek bir kesintisiz container olacak. Yapı şu şekilde:
  ```
  ┌─────────────────────────────────────┐
  │  [icon]  ███ fiziksel notch ███  [icon]  │  ← Notch bar (top)
  ├─────────────────────────────────────┤
  │         Sub-Header (tab bar vb.)        │
  ├─────────────────────────────────────┤
  │                                         │
  │           Content Area                  │
  │                                         │
  └─────────────────────────────────────┘
  ```
  `NotchWindow` ve `TerminalPanel` ayrı pencereler yerine tek bir `NSPanel` içinde hiyerarşik view'lar olarak yeniden yapılandırılacak.

## Visual Enhancements
- [ ] **Symbol Effects:** SF Symbols animasyonları (`.symbolEffect`) çalışmıyor veya ikonların kaybolmasına neden oluyor. Alternatif tetikleyiciler (`@State`) ile tekrar denenmeli.
- [ ] **Dynamic Island Feel:** Çentiğin sağa sola uzama animasyonundaki akıcılık ve köşe kavislerinin (Squircle) ekranla tam uyumu ince ayar bekliyor.
