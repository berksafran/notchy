# Notchy Design Architecture

This document describes how Notchy integrates with the physical MacBook notch and expands its functionality using a pill-shaped overlay ("Hap") and a sliding panel.

## Terminology

| Term | Description | Code |
|------|-------------|------|
| **Hap** | The black pill-shaped overlay that sits directly over the physical hardware notch. Always visible, expands on hover/status change. | `NotchWindow` + `NotchPillView` + `NotchPillContent` |
| **Kulak (Ear)** | The rounded protrusions that extend left/right from the Hap when hovered. | `NotchPillView.earProtrusion` |
| **Panel** | The main floating terminal/settings window that slides down from behind the Hap. | `TerminalPanel` |
| **Notch** | The physical hardware camera cutout on the MacBook display. | — |

---

## 1. Idle State

In its default state, Notchy is completely invisible. The Hap hides perfectly behind the physical hardware notch — same width, same position, 100% black.

```text
               Top Edge of Screen (y = 0)
──────────────────────────────────────────────────────────
           ╭──────────────────────────────╮
           │                              │
           │        Physical Notch        │  <-- Hap sits here, invisible
           │         (Hardware)           │
           │                              │
           ╰──────────────────────────────╯
──────────────────────────────────────────────────────────
```

---

## 2. Status Active (Hap Expands, No Hover)

When Claude is working/waiting, the Hap expands slightly wider (+80pt) and shows status icons on the right. No ears visible yet.

```text
               Top Edge of Screen (y = 0)
──────────────────────────────────────────────────────────
       ╭──────────────────────────────────────╮
       │  🤖              │              ⏳/✔️/✋ │
       │        Physical Notch (Hardware)      │
       ╰──────────────────────────────────────╯
──────────────────────────────────────────────────────────
```

States:
- `⏳` White Spinner — Claude is working
- `✔️` Green Check — Task completed
- `✋` Yellow Hand — Waiting for user input

---

## 3. Hover State (Kulaklar Extends, Matches Panel Width)

When the user hovers over the Hap, it expands to **match the Panel width exactly**. Rounded "kulak" (ear) protrusions appear at the bottom corners, creating a smooth concave transition. The Hap and Panel form one seamless continuous shape.

```text
               Top Edge of Screen (y = 0)
──────────────────────────────────────────────────────────
  ╭──────────╭──────────────────────────────╮──────────╮
  │  >_  🤖  │                              │  ⏳   ⚙️  │
╭─╯          │        Physical Notch        │          ╰─╮
│  Left Ear  │         (Hardware)           │  Right Ear │
╰────────────╯                              ╰────────────╯
  [Region A]          [Region B]              [Region C]
──────────────────────────────────────────────────────────
```

### Regions:
- **[Region A] Left Ear (Sol Kulak):**
  - `>_` Terminal icon — navigates to terminal tab
  - `🤖` Bot face — visible when Claude is active
- **[Region B] Physical Notch:** Hardware dead zone. Nothing is drawn here.
- **[Region C] Right Ear (Sağ Kulak):**
  - `⏳` / `✔️` / `✋` — status icons
  - `⚙️` Settings icon — visible on hover

**Key behavior:** The Hap width on hover equals `panel.frame.width`, centered on screen. This makes the Hap and Panel visually merge into one continuous element.

---

## 4. Panel Revealed (Smooth Slide Down)

Clicking the Hap slides the Panel down. The Panel's top edge connects seamlessly with the bottom of the Hap.

```text
               Top Edge of Screen (y = 0)
──────────────────────────────────────────────────────────
  ╭──────────╭──────────────────────────────╮──────────╮
  │  >_  🤖  │        Physical Notch        │  ⏳   ⚙️  │
╭─╯          │         (Hardware)           │          ╰─╮
╰────────────┴──────────────────────────────┴────────────╯
╭────────────────────────────────────────────────────────╮
│  [Session 1 ×]  [Session 2 ×]              [+]  [Pin]  │  ← Tab Bar (black)
├────────────────────────────────────────────────────────┤
│                                                        │
│   ~ % cd my-project                                    │  ← Terminal Content
│   ~ % claude                                           │
│   [Claude output...]                                   │
│                                                        │
╰────────────────────────────────────────────────────────╯
```

### Layout Modes:
- **Classic:** Panel sits just below the notch (8pt overlap to bridge the hover gap).
- **Unified:** Panel covers the full screen height from top, Hap is not used.

### Panel:
- **Tab Bar:** Solid black, blends with the Hap above it. Green/gray dot per tab shows if the Xcode project is still open.
- **Content Area:** Solid black background with embedded terminal (SwiftTerm).
