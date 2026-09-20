# TidyTray

The definitive unified system tray and bar widget organizer for **[Omarchy](https://omarchy.org/)** (Quickshell on Wayland / Hyprland).

TidyTray synthesizes the best architectural ideas and UX conventions from 7 leading bar organizer plugins into a single, high-craft, keyboard-accessible component:
- **`omarchy-tinytray`**: Dual-citizen hosting of both SNI apps and bar widgets, with smart deduplication (suppresses native Dropbox tray icon when Omarchy's Dropbox widget is active) and ghost item filtering (LocalSend).
- **`omaice`**: Dynamic layout concealment and floating dock strip mode with zero bar-neighbor shifting.
- **`nook`**: Floating card drawer positioned below the bar with smooth interactive drag-and-drop.
- **`omarchy-tray`**: Recursive DBus submenu stack (`QsMenuOpener`) that eliminates Quickshell's platform submenu limitation, plus strict superset tray features.
- **`omarchy-flat-tray` & `gamut`**: "Flat" full-glanceability mode where all icons live directly on the bar and the expand chevron disappears whenever the drawer is empty.
- **`Omarchy-drawer`**: Structured popup panel with Grid and List views, instant search filtering, and quick toggle switches.

---

## Features

### 1. Four Presentation Modes
Tailor how TidyTray fits your desktop workflow:
- **`inline` (Slide-out)**: Slides out smoothly along the bar beside the indicator using cubic easing (`Easing.OutCubic`). Ideal when placed at the edge of the bar (e.g. first item on the right or last on the left).
- **`dropdown` (Floating Strip)**: Reveals items in a compact floating strip docked directly beneath the bar. **Zero bar shifting** — clock, workspaces, and media widgets stay completely still.
- **`drawer` (Card Popout)**: Opens an interactive card featuring instant search, badge metrics, and quick switching between Icon Grid and Detailed List views.
- **`flat` (Full Visibility)**: Unfolds all icons and widgets directly into the bar row. The indicator button automatically hides when no items are tucked away.

```text
INLINE MODE:    [ Pinned ] [ > ] [ App1 ] [ App2 ] [ App3 ]  (slides out on bar)
DROPDOWN MODE:  [ Pinned ] [ v ]
                           +---------------------------+
                           |  App1   App2   App3   ... |  (floats under bar)
                           +---------------------------+
DRAWER MODE:    [ Pinned ] [ v ]
                           +---------------------------+
                           | [ Search...             ] |
                           | (::) Grid    (=) List     |
                           | [Icon] App1   [Icon] App2 |
                           +---------------------------+
FLAT MODE:      [ Pinned ] [ App1 ] [ App2 ] [ App3 ]        (always visible, no chevron)
```

### 2. Dual-Domain First-Class Citizens (SNI + Bar Widgets)
- **StatusNotifierItem (SNI / DBus)**: Full support for theme icons, HiDPI raster pixmaps, recursive DBus submenus, scroll events (volume, etc.), left-click, right-click, and middle-click.
- **Hosted Bar Widgets**: Drag any bar widget (Bluetooth, Network, Media, Power, custom modules) into TidyTray. Widgets retain their full interactive state, click handlers, popouts, and tooltips.

### 3. Interactive Drag & Drop
- **Capture into Tray**: Drag any widget off the bar directly onto TidyTray. The animated `DropCaret` marker shows where it will land.
- **Reorder Inside**: Drag items within TidyTray to adjust their order.
- **Restore to Bar**: Drag a widget out of TidyTray back onto the bar to release it.

### 4. Management Hub with 3D Card Flip
- Right-click the indicator button or press `s` to trigger a **3D perspective card flip**.
- On the back:
  - Instant search across all installed plugins and tray apps.
  - 1-click toggles to Pin, Hide, or Eject items.
  - Real-time display mode switcher.
  - Indicator style selector (`chevron`, `dot`, `dots`, `plus`, `none`).
  - Auto-hide countdown slider (`rehideSeconds`).

### 5. Wayland Keyboard-First
Fully operable without touching the mouse:
- **`Arrow keys`**: Navigate through tray items, menus, and submenus.
- **`Tab` / `Shift+Tab`**: Cycle focus across interactive controls.
- **`s`**: Flip to Settings / Management.
- **`Esc`**: Close panel or return one level up in submenus.

---

## Installation

### Recommended (Quick Install)

Install directly via the Omarchy plugin CLI:

```bash
omarchy plugin add https://github.com/jvlianodorneles/tidytray.git --enable
```

> [!TIP]
> Because TidyTray declares `"clonedFrom": "omarchy.tray"` in its `manifest.json`, enabling it **automatically replaces the stock tray** in your bar without duplicating icons or requiring manual editing of `shell.json`.

Then reload the shell:

```bash
omarchy restart shell
```

### Moving TidyTray on the Bar

To position TidyTray in a specific section:

```bash
omarchy bar move io.github.jvlianodorneles.tidytray --section right
```

For the smoothest slide-out animation in `inline` mode, keep TidyTray at the **inner edge** of its section (first entry of `right`, or last of `left`), allowing the drawer to expand into the bar's empty middle.

---

## Uninstallation & Removal

### 1. Remove TidyTray

To cleanly remove TidyTray from your system:

```bash
omarchy plugin remove io.github.jvlianodorneles.tidytray --yes
```

### 2. Restore the Stock System Tray (Optional)

If you ever wish to re-enable Omarchy's built-in system tray widget:

```bash
omarchy plugin enable omarchy.tray --section right
```

Then reload the shell to apply:

```bash
omarchy restart shell
```

---

## Configuration Reference

Settings can be toggled interactively in the 3D Management Hub (`s` key or right-click) or edited directly in `~/.config/omarchy/shell.json`:

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `displayMode` | `enum` | `"inline"` | Presentation mode: `"inline"`, `"dropdown"`, `"drawer"`, or `"flat"` |
| `trigger` | `enum` | `"click"` | Open trigger: `"click"` or `"hover"` |
| `indicatorIcon` | `enum` | `"chevron"` | Indicator glyph: `"chevron"`, `"dot"`, `"dots"`, `"plus"`, `"none"` |
| `rehideSeconds` | `integer` | `0` | Seconds before auto-collapsing when inactive (`0` disables) |
| `revealDuration`| `integer` | `200` | Transition duration in milliseconds |
| `deduplicateKnown`| `boolean` | `true` | Suppress redundant tray icons when native bar widget exists (e.g. Dropbox) |
| `pinned` | `array` | `[]` | List of item IDs pinned to always stay visible on the bar |
| `hidden` | `array` | `[]` | List of item IDs hidden from daily sight (manageable in hub) |
| `widgets` | `array` | `[]` | List of captured bar widgets hosted inside TidyTray |

---

## Keyboard Shortcuts

| Key | Action |
| :--- | :--- |
| `Left` / `Right` | Move focus across bar items |
| `Up` / `Down` | Walk dropdown or submenu rows |
| `Enter` / `Space` | Activate selected item or toggle submenu |
| `s` | Flip between Tray and Management Hub |
| `Esc` | Close open panel or navigate back in submenus |

---

## Acknowledgments

TidyTray stands on the shoulders of the great work done by the Omarchy and Quickshell community:
- **Vincent Ritter** ([omarchy-tinytray](https://github.com/vincentritter/omarchy-tinytray))
- **TerrifiedBug** ([omaice](https://github.com/TerrifiedBug/omaice))
- **Katsari** ([nook](https://github.com/Katsari/nook))
- **Ty Richards** ([omarchy-tray](https://github.com/TyRichards/omarchy-tray))
- **WhiteWebDev** ([omarchy-flat-tray](https://github.com/WhiteWebDev/omarchy-flat-tray))
- **lubabs770** ([gamut](https://github.com/lubabs770/gamut))
- **Aly Sarhan** ([Omarchy-drawer](https://github.com/alyayman921/Omarchy-drawer))

---

## License

MIT © [Juliano Dorneles](https://github.com/jvlianodorneles)
