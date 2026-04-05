# Notchy — Session Memory

Bu dosya Claude session'ları arasında bağlamı korumak için tutulur.

---

## Sıradaki İş

**Layout 2 (Unified) — test & polish**

Implementasyon tamamlandı, build başarılı. Sıradaki adımlar:

1. **Görsel test**: Unified mod açıkken panelin notch alanını doğru kapatıp kapatmadığını kontrol et.
2. **Hover tracking (unified)**: Unified modda `NotchWindow` gizlendiği için hover yok — NotchBar'daki butonlar paneli açmalı mı? Ya da her zaman görünür olması mı gerekiyor?
3. **Settings Window** (`SettingsWindow.swift`): Ayrı settings window varsa orada da layout picker eklenebilir.
4. **NotchBar status icons**: Unified modda NotchBar, NotchPillContent gibi status ikonları gösterebilir (spinner, checkmark vb.).

---

## Tamamlanan Özellikler

- ✅ `LayoutStyle` enum (`classic` / `unified`) — `SettingsManager` + UserDefaults
- ✅ `NotchyLayoutStyleChanged` notification
- ✅ `TerminalPanel` Y positioning: unified modda `screen.maxY - panelHeight`
- ✅ `NotchBar` view — notchHeight yüksekliğinde, sol `apple.terminal` + sağ `gear` butonları
- ✅ `UnifiedPanelShape` — sadece alt köşeler yuvarlatılmış
- ✅ `PanelContentView` — unified modda NotchBar + farklı clip shape
- ✅ `AppDelegate` — `layoutStyle == .unified` ise NotchWindow gizlenir; `.classic`'e dönünce yeniden oluşturulur
- ✅ Settings UI — "Panel layout" segmented picker (Classic / Unified)

---

## Mimari Kararlar

| Konu | Karar |
|------|-------|
| Unified trigger | Status item click + hotkey (hover yok, NotchWindow gizli) |
| NotchBar yüksekliği | `NSScreen.builtIn` + `auxiliaryTopLeftArea` ile dinamik hesaplanır |
| Unified clip shape | `UnifiedPanelShape` — düz üst, yuvarlatılmış alt köşeler |
| Settings persistence | `UserDefaults` key: `"layoutStyle"`, default: `.classic` |
| Hover ikonlar | Sol: `apple.terminal`, Sağ: `gear` |
| @Observable pattern | Singleton (`NotchPillModel.shared`) |

---

## Açık Kalan Maddeler

- [ ] Container Gap (ayrı NotchWindow ile panel arasındaki boşluk) — Layout 2 ile bu sorun yok
- [ ] Symbol Effects — animasyonlu SF Symbol efektleri
- [ ] Unified modda hover tracking — panel her zaman görünür mü olmalı?
- [ ] NotchBar'a status ikonları (spinner/checkmark) eklenmesi
