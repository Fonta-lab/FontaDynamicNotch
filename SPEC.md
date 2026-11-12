# Fonta's Dynamic Notch — Product & Technical Spec

Version 1.0 · 2026-11-10 · Personal-use macOS app (not for distribution)

Target machine: MacBook Air M5, macOS 27.2.1, plus optional external monitor(s).

Confidence tags used in this document:
- **[Certain]** documented public API or verified behaviour.
- **[Likely]** strong inference / widely used technique, must still be verified on the target macOS.
- **[Guess]** starting value or assumption; tune during development.

---

## 0. Summary

A notch app in the style of a "Dynamic Island" for macOS. It lives around the MacBook's physical notch (and draws a fake notch on screens without one). Closed, it shows the album cover and either animated bars or a running timer/stopwatch. On hover, it springs open into a panel with:

- **Top bar:** Home/Files tabs, screen brightness, keyboard brightness (left of the notch); Timer, Stopwatch, Counter selectors (right of the notch).
- **Home tab:** Spotify now-playing (cover, title, artist, progress, transport controls), system volume and output-device picker, and a right-hand tool panel (timer / stopwatch / counter).
- **Files tab:** a temporary file shelf with AirDrop and a Trash drop zone.

Everything visual is customizable from a separate macOS-style Settings window: themes, colors, corner radii, shadows, icon size, slider styles, module order, and full spring parameters for each animation.

---

## 1. Platform & project setup

| Item | Decision |
|---|---|
| Language / UI | Swift 6, SwiftUI for views, AppKit for windows/system integration |
| Project generation | **XcodeGen** (`project.yml` committed; `.xcodeproj` regenerated). Lets Claude Code manage the project from the terminal. |
| Target name | `FontaDynamicNotch` (no apostrophe in target/product names to avoid path issues) |
| Display name | `Fonta's Dynamic Notch` via `CFBundleDisplayName` |
| Bundle ID | `com.fonta.dynamicnotch` |
| Deployment target | macOS 14.0 Sonoma (lowered from 26.0 at the user's request for v0.2; the user runs 27.2.1). Target hardware: Apple Silicon Macs with a notch. |
| App Sandbox | **OFF**. Required for Spotify scripting, private frameworks and trashing arbitrary files. |
| Hardened Runtime | ON, with entitlement `com.apple.security.automation.apple-events` |
| Info.plist | `LSUIElement = YES` (no Dock icon); `NSAppleEventsUsageDescription` ("Used to show and control what's playing in Spotify.") |
| Signing | Apple ID "Personal Team" (free) Apple Development certificate. **Do not use ad-hoc signing**: macOS ties permissions (Automation, Notifications) to the signature, and ad-hoc builds would re-prompt for permissions after every build [Likely]. |
| Version control | git, one commit per completed milestone step |
| Launch at login | `SMAppService.mainApp.register()/unregister()` [Certain] |

**Menu bar icon:** an `NSStatusItem` with "Settings…" and "Quit". It can be hidden in Settings. Right-clicking the open notch shows the same menu, so Settings is always reachable even with the icon hidden.

---

## 2. Architecture

```
App (SwiftUI @main + NSApplicationDelegateAdaptor)
├── ScreenManager           — one NotchController per NSScreen, hot-plug, lid state
│   └── NotchController     — owns NotchPanel (NSPanel) + NotchViewModel for that screen
├── MouseTracker            — global/local mouse monitors → hover state per screen, click-through
├── Services (shared, @MainActor @Observable singletons)
│   ├── SpotifyService      — now playing, artwork, transport, shuffle/repeat
│   ├── AudioService        — CoreAudio volume, mute, output devices
│   ├── BrightnessService   — built-in display brightness (private API, feature-flagged)
│   ├── KeyboardLightService— keyboard backlight (private API, feature-flagged)
│   ├── TimerStore          — up to 3 timer chips (starred or running) + a draft, run state, persistence
│   ├── StopwatchStore      — one stopwatch + laps, persistence
│   ├── CounterStore        — named counters, persistence
│   ├── AlarmService        — looping alarm sound, ringing state
│   ├── ShelfStore          — in-memory file shelf, AirDrop, Trash
│   └── ColorExtractor      — dominant color from artwork (cached per track)
├── SettingsStore           — AppSettings + Themes (Codable JSON), live-applied
└── SettingsWindow          — SwiftUI Settings scene, sidebar layout
```

Rules:
- All notch windows render **the same shared state**. Hover/open state is **per screen**.
- Services are event-driven. **No polling loops while closed and idle** (see §12).
- Each private-API feature sits behind a protocol with an `isAvailable` check. If unavailable, its UI is removed, not disabled.
- Blocking work (AppleScript, file I/O, image decoding) never runs on the main thread.

---

## 3. Windows, geometry, screens

### 3.1 NotchPanel
- `NSPanel` subclass, `styleMask: [.borderless, .nonactivatingPanel]`, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false` (the shadow is drawn in SwiftUI).
- Level above the menu bar: `.statusBar` or `.mainMenu + 3` [Likely]. Pick whichever sits over menu bar items without covering system alerts.
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`. **Do not** include `.fullScreenAuxiliary` (the notch must disappear in full screen, §3.4).
- `canBecomeKey = false` normally. Allow key only if a text field ever needs it (none in v1).
- The frame is fixed at the **maximum open size**, anchored top-center of the screen. The SwiftUI content draws the visible shape inside it.
- **Click-through:** `ignoresMouseEvents` is toggled by MouseTracker. It is `false` only while the cursor is inside the currently visible notch shape. Everything else passes clicks through to the menu bar and apps below.

### 3.2 Notch geometry
- Real notch: `notchHeight = screen.safeAreaInsets.top`; `notchWidth = screen.frame.width − auxiliaryTopLeftArea.width − auxiliaryTopRightArea.width` [Certain: APIs exist since macOS 12].
- Fake notch (screen without a notch, `safeAreaInsets.top == 0`): height = menu bar height (`screen.frame.maxY − screen.visibleFrame.maxY`, falling back to `NSStatusBar.system.thickness`). Width = the built-in notch width if known, else 185 pt [Guess].
- Expose a debug overlay (Settings → Advanced) that outlines the computed notch rect, closed rect, open rect and hot zone.

### 3.3 Multiple screens
- One NotchController per connected screen. **Default: notch on all screens**, with a Settings option "Main display only".
- Recreate controllers on `NSApplication.didChangeScreenParametersNotification`. Screens are identified by `CGDirectDisplayID`.
- Mirrored displays: one notch only.
- **Lid closed** (no screen with `CGDisplayIsBuiltin == true`): the built-in notch controller is gone. On the remaining notches, the **screen-brightness and keyboard-brightness buttons are removed** and the layout reflows.
- **External screen notch, lid open:** screen brightness button removed (it would control the wrong display), keyboard brightness kept.
- Fake notch when idle: stays visible as a black pill the size of a real notch, so there is something to hover. Setting: "Show fake notch when idle" (default ON).

### 3.4 Full screen
- When a full-screen app occupies a screen, that screen's notch disappears. Other screens are unaffected.
- Primary mechanism: no `.fullScreenAuxiliary`, so the panel does not appear in full-screen Spaces [Likely].
- Fallback if needed (verify in M0): on `NSWorkspace.activeSpaceDidChangeNotification` / frontmost-app change, check via `CGWindowListCopyWindowInfo` whether a layer-0 window covers the full frame of that screen, then fade the panel out.

---

## 4. States & visibility

### 4.1 Closed state
Height = notch height ("as tall as the menu bar"), pure black, merged with the physical notch.

```
 [ cover ]███████ real notch ███████[ bars | time ]
   left wing                          right wing
```

| Situation | Left wing | Right wing |
|---|---|---|
| Nothing playing, nothing running | hidden | hidden → notch shrinks to the real notch (invisible) |
| Music active, no timer/stopwatch running | album cover | animated bars |
| Music active + timer/stopwatch running | album cover | time |
| No music, timer/stopwatch running | hidden | time |

- **"Music active"** = Spotify is running and the player is `playing`, or `paused` for less than 10 minutes (setting, default 10 min). A paused state shows the cover with the bars frozen and dimmed.
- **Which time is shown:** the running timer with the least remaining time. If no timer is running, the running stopwatch. Paused timers/stopwatch do not show in the closed state.
- Counters never appear in the closed state.
- Closed time format: `m:ss` under 1 h, `h:mm:ss` above; stopwatch without centiseconds. Updates at **1 Hz** only.
- Wing appear/disappear uses the "wings" spring (§9).

### 4.2 Open state
Triggered by hovering the visible closed shape (or the real notch area when idle) for **0.10 s** (setting). Closes **instantly** when the cursor leaves the open shape (close delay setting, default 0 s).

Do **not** close while:
- a slider drag or other mouse-down that began inside the notch is in progress;
- an alarm is ringing (§7.4);
- the right-click menu or output-device list is open;
- a file drag is in progress over the notch.

### 4.3 Open layout (from the user's drawing)

```
 ╭─fillet                                                              fillet─╮
 │ [⌂|🗂] [☀︎] [⌨︎☀︎]   ████ real notch ████   [⏲ timer] [⏱ stopwatch] [▦ counter] │  ← top bar (height = notch height)
 │ ┌──────────┐  🔈━━━━━━━●━━━━━━  [output]         ┌──────────────────────┐ │
 │ │          │  Song name                          │  [chips / name]       │ │
 │ │  COVER   │  Artist                             │    12:34.56           │ │  ← right tool panel
 │ │          │  ━━━━━━━●━━━━━━━━━━━━━━━━           │  [ctrl] [ctrl] [ctrl] │ │
 │ └──────────┘  1:20                        3:30   └──────────────────────┘ │
 │               ⤮    ⏮    ⏯    ⏭    ⟳                                       │
 ╰──────────────────────────────────────────────────────────────────────────╯
```

- Default open size: **604 × 176 pt** including the top bar (the user's own setting, made the default in v0.4; 600 × 190 before). Configurable.
- Top corners have **outward concave fillets** that merge into the menu bar (as in the drawing). Bottom corners are rounded.
- **Top bar left group** (left of the real notch), default order: Home/Files toggle (Boring-Notch style pair of icons), Screen brightness, Keyboard brightness.
- **Top bar right group** (right of the real notch), default order: Timer, Stopwatch, Counter. The selected tool is highlighted; clicking selects which tool the right panel shows.
- Both groups are reorderable and individually hideable in Settings (§10).
- **Right tool panel on open:** the running timer/stopwatch if any (same priority as §4.1), otherwise the last tool used.

### 4.4 Background & shadow (open state)
- If artwork exists: background = **dominant color of the cover** (§5.4), filling the whole open shape. **No fade around the notch** (removed at the user's request after M3; the earlier oval and short-rectangle fades were tried and rejected).
- No artwork / nothing playing: background = theme's fallback color (default **pure black**).
- Outer shadow under the open notch: theme setting (default black, opacity 0.35, radius 12, y-offset 4 [Guess]), similar to Boring Notch's faint shadow.
- Closed state is always pure black (no tint), so it blends with the notch. Exception (v0.3): a Liquid Glass theme with "Glass also when closed" on.
- **Liquid Glass surface (v0.3, user request):** a theme's `surfaceStyle` can be `liquidGlass`. On macOS 26+ the notch shape is drawn with `glassEffect` inside a `GlassEffectContainer` (stable `glassEffectID`), its shape animated with the open/close springs; macOS 14/15 fall back to `.ultraThinMaterial`. Options: variant regular/clear, tint (none or colour + intensity; the artwork colour wins while music plays if "Use artwork colour" is on), dimming layer for legibility, glass when closed (default off). Inside the notch the colour scheme is forced to dark. Inner buttons keep their soft highlights (no glass on glass).
- Text/icons stay legible: the dominant color is darkened until white text passes a contrast ratio of 4.5:1 (setting "Max background brightness").

---

## 5. Music (Spotify only)

### 5.1 Data source
Spotify's AppleScript interface, **not** MediaRemote (which is restricted since macOS 15.4) [Certain that Spotify is scriptable].

- **Never launch Spotify by accident:** before any script, check `NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")`. `tell application "Spotify"` would start it otherwise [Certain].
- **Change events:** observe `DistributedNotificationCenter` notification `com.spotify.client.PlaybackStateChanged` [Likely]. Its `userInfo` carries state, name, artist, track ID, duration and position. On each event, run one script to refresh the full state.
- **Progress bar:** interpolate locally from `(position, timestamp, isPlaying)`. Resync from Spotify on each event, and every 5 s **only while the notch is open and playing**. No timers when closed.
- Run all AppleScript on **one dedicated serial background queue** (NSAppleScript is not thread-safe). Never block the main thread.
- Properties to read: `player state`, `player position`, `shuffling`, `repeating`, and from `current track`: `id`, `name`, `artist`, `album`, `duration` (ms), `artwork url`.
- Commands: `playpause`, `next track`, `previous track`, `set player position to x`, `set shuffling to bool`, `set repeating to bool`.
- Artwork: download `artwork url` with URLSession, decode off-main, cache in memory by track ID (LRU of 20).
- **Permission:** the first script triggers the macOS Automation prompt. If denied, the media area shows "Allow Spotify control" → opens System Settings › Privacy & Security › Automation.

### 5.2 Media UI (Home tab)
- Cover (left, rounded; theme radius).
- Volume row **directly under the real notch, above the song info**: speaker icon (click = mute toggle), system volume slider, output-device button (§6).
- Song name and artist. Long titles scroll as a marquee on hover (setting: marquee on/off).
- Progress slider (draggable; seeks on release) with current time on the left and length on the right.
- Controls: shuffle, previous, play/pause, next, repeat.
- **Repeat** is an on/off toggle. Spotify exposes only a boolean, so "repeat one track" is not available from the notch [Likely]. Verify in M0; if a three-state value turns out to be readable, show it.
- **Spotify not running:** placeholder with an "Open Spotify" button (launches it). Ads, podcasts or local files without artwork: placeholder cover, black background.

### 5.3 Animated bars (closed right wing)
- Fake visualizer, not real audio analysis (decided by the user).
- 5 bars [Guess], random target heights, smooth spring between targets. Color = dominant artwork color (lightened) or theme color (setting).
- Animate **only** when music is playing and the wing is visible; otherwise freeze. Use `TimelineView(.animation(minimumInterval: 1/30))` or equivalent: cap at 30 fps.
- Settings: bar count (3–8, default 4), speed (default 0.3), color source.

### 5.4 Dominant color
- Downscale the artwork to ~40×40, cluster (k-means, k=5), and prefer the largest cluster with saturation > 0.2 and brightness between 0.15 and 0.9. Fall back to the average color.
- Compute off-main and cache by track ID.
- Settings: "Use artwork color" on/off, intensity (0–1), max background brightness.

---

## 6. Audio (system)

CoreAudio, public API [Certain].

- **Device list:** `kAudioHardwarePropertyDevices`, filtered to devices with output streams (`kAudioDevicePropertyStreams`, output scope). Show only connected devices; CoreAudio lists only those.
- **Name and icon:** `kAudioObjectPropertyName`; icon from `kAudioDevicePropertyTransportType` (built-in → laptop speaker, Bluetooth → headphones/speaker, AirPlay → AirPlay, USB/HDMI → cable/display).
- **Current device:** `kAudioHardwarePropertyDefaultOutputDevice`. Clicking another device in the list sets it as default.
- **Volume:** `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` on the default output device. **Mute:** `kAudioDevicePropertyMute`. Devices with no software volume (some HDMI) → slider disabled with tooltip.
- **Listeners** (`AudioObjectAddPropertyListenerBlock`) for the device list, default device, volume and mute, so the UI follows changes made elsewhere (keyboard keys, Control Center).
- Output picker UI: the button opens an inline dropdown under the volume row, listing devices with a checkmark on the current one. The notch stays open while it is shown.

---

## 7. Tools (right panel)

### 7.1 Timers
Redesigned in v0.4 at the user's request (replaces the 5 named presets).
- **Chips = timers.** Up to **3 chips** on top of the timer box, in 3 equal slots, in the order they were added. A chip is a timer that is **starred** (kept, shows its length, e.g. "5:00") or **started** (running/paused/ringing: shows its live countdown and a dot — accent when running, dim when paused, red when ringing). **Several timers can run at the same time** (one per chip).
- **+ chip:** same shape as the timer chips, in the next free slot whenever there are fewer than 3 chips. It starts a **new timer** (the "draft") with the last length set; the + is highlighted while the draft is the one shown. Start (▶) makes the draft a running chip; the star keeps it. Selecting another chip lets an untouched draft go.
- The middle shows the **selected** timer. While it's idle its length is set right there: hovering a number (hours, minutes or seconds) gives it a soft highlight; scrolling over it or dragging it up/down changes it (up = more; 1 h / 1 min / 1 s steps, 1 s – 23:59:59). No arrows or extra buttons (arrows were tried and rejected by the user). On a starred timer this changes its saved length.
- **Star:** keeps the selected timer as a chip; star again to un-star (an idle un-starred timer leaves the chip row). A timer that wasn't starred leaves the chips once it has ended and the alarm is stopped (or it's reset while another chip is shown).
- **At most 3 chips**: starring or starting a 4th shows a short message "3 timers already saved" (≈1.6 s) over the chip row. Settings › Timers lists the starred timers with Remove.
- Controls: **Start/Pause** and **Reset** (panel buttons, bottom row) and a **plain star** symbol with no box **right of the time** (outline = not saved, filled = saved); an equal empty space on the left keeps the time centred.
- State: `idle | running(endDate) | paused(remaining) | ringing`.
- Scheduling: a single task that sleeps until the nearest `endDate`, recomputed whenever a timer changes and on `NSWorkspace.didWakeNotification`. No per-second ticks unless a time is visible.
- **Persistence and reboot behaviour:**
  - App running, timer ends → ring (§7.4).
  - Mac was asleep when it ended → ring on wake.
  - App was not running (quit/reboot) when it ended → on next launch, post a notification "⏲ <length> timer ended at HH:MM" and set that timer to idle. No ringing.
  - Still running across a reboot (end date in the future) → keeps counting down (wall-clock `endDate`).
- Migration: from v0.3, the selected preset becomes the shown timer (no stars); from the early-0.4 single timer, its starred lengths become starred chips.

### 7.2 Stopwatch
- One stopwatch. State: `idle | running(startDate, accumulated) | paused(accumulated)`, plus `laps: [TimeInterval]`.
- Controls: Start/Pause, Lap, Reset. Reset clears everything; no lap history is kept.
- Display: `mm:ss.cc` (h:mm:ss.cc after 1 h), refreshed at ~30 Hz **only while open and visible**.
- Laps: the last lap shows small under the main time. Hovering the time shows a scrollable list of all laps.
- Survives reboot: wall-clock based (`startDate`), so time keeps counting while the Mac is off.

### 7.3 Counters
- Multiple named counters `{ id, name, value: Int }`. Values can go negative.
- Panel: counter name with ‹ › arrows to switch, large value, buttons **−1**, **+1**, **Reset** (to 0).
- Create, rename, delete and reorder in Settings › Counters. At least one counter always exists ("Counter").
- Persisted; survives reboot. Never shown in the closed notch.

### 7.4 Alarm
- When a timer ends: `AVAudioPlayer` loops the selected sound (`numberOfLoops = -1`) **until dismissed**.
- The notch **opens automatically on the screen where the mouse is**, showing the timer's length and a large **Stop** button. It does not close on mouse-leave while ringing.
- Several timers ringing at once: their lengths are listed, and one Stop dismisses all.
- Stop from any screen's notch stops it everywhere. The sound plays once (not once per screen).
- Settings: sound chosen from `/System/Library/Sounds` or a user-imported audio file (copied into Application Support), preview button, alarm volume (relative).
- If the app cannot play sound (e.g. the output device disappears), post a notification as a fallback.

---

## 8. Files tab (shelf, AirDrop, Trash)

Modelled on Boring Notch's shelf.

- **Opening by drag:** while the user drags files (pasteboard `.drag` contains file URLs) over the notch's hot zone, the notch opens **immediately (no 0.1 s delay)** directly on the Files tab.
- **Shelf:** dropped files are stored as **references** (URLs, security-scoped bookmarks not needed: no sandbox), shown as a horizontal scrolling row of QuickLook thumbnails (`QLThumbnailGenerator`) with names. Hovering an item shows an ✕ to remove it; "Clear all" button.
- **Drag out:** items can be dragged from the shelf to Finder or any app (`NSItemProvider` with the file URL).
- **Not persistent:** the shelf empties on quit/reboot (user's choice).
- **AirDrop zone:** dropping files on it, or clicking it with shelf items selected, calls `NSSharingService(named: .sendViaAirDrop)?.perform(withItems:)` [Certain].
- **Trash zone:** dropping files on it (from the shelf **or straight from Finder**) calls `FileManager.default.trashItem(at:resultingItemURL:)` immediately. No confirmation, no undo (user's choice). Files trashed from the shelf are also removed from the shelf. On failure (e.g. network volume), shake the zone and show a short error.
- Files only in v1. Dropped text or images from browsers are ignored (possible v2).

---

## 9. Animations

All springs use SwiftUI springs, exposed in Settings with **full parameters**:
- Simple mode: `duration`, `bounce`.
- Advanced mode: `response`, `dampingFraction`, `blendDuration`.

Separate spring per animation, each with a live **Preview** button and "Reset to default":

| Animation | Default (response / damping); since v0.4 the user's own tuning |
|---|---|
| Open | 0.47 / 0.78 |
| Close | 0.35 / 0.90 |
| Closed wings appear/disappear | 0.40 / 0.80 |
| Brightness slider expand/collapse | 0.12 / 1.5 |
| Tab switch (Home ↔ Files, tool switch) | 0.35 / 0.90 |
| Alarm auto-open | 0.32 / 0.65 |

Also configurable: hover-open delay (default 0.10 s) and close delay (default 0 s).

**Brightness controls (top bar):** hovering the screen-brightness or keyboard-brightness icon expands it horizontally into a slider capsule (neighbouring icons slide aside); leaving collapses it.

---

## 10. Settings window

A macOS-style window (SwiftUI, sidebar navigation like System Settings). Changes apply **live**.

1. **General:** launch at login (toggle), show notch on all screens / main display only, show fake notch when idle, menu-bar icon on/off, hover-open delay, close delay, "paused music stays visible for N minutes".
2. **Appearance › Themes:** theme list; built-in "Default" (since v0.3 its values are the user's own settings: Liquid Glass, clear variant, glass also when closed, capsule knobs; `Theme()` keeps the v0.2 values as fallbacks for missing keys; editable in place since v0.3, with "Reset to Original"; edits saved as themes/default.json; its Surface can be Solid or Liquid Glass, so there is no separate glass theme) + user themes; create, duplicate, rename, delete; **export/import as JSON**. A theme contains:
   - **Colors:** fallback background, primary text, secondary text, accent, icon color, slider track, slider fill, slider knob, use-artwork-color toggle, artwork intensity, max background brightness.
   - **Corner rounding:** top fillet radius, open bottom radius, closed bottom radius, cover radius (open), cover radius (closed), button radius.
   - **Shadow:** on/off, color, opacity, radius, y-offset.
   - **Surface:** Solid / Liquid Glass, glass variant, transparency (Clear ↔ Tinted), tint + intensity, dimming, glass when closed.
   - **Icon size** (top bar and controls separately).
   - **Sliders:** height, knob size, knob shape (circle / capsule / none), knob visible only on hover, fill style (solid / artwork color).
3. **Layout & Modules:** drag-to-reorder the left and right top-bar groups; show/hide each module (Home/Files, Screen brightness, Keyboard brightness, Timer, Stopwatch, Counter); open width/height; closed wing width.
4. **Animations:** §9 springs, each with preview and reset.
5. **Music:** Spotify permission status and button; bars count, speed and color source; marquee on/off.
6. **Timers:** starred times (list, remove); alarm sound picker, import, preview; alarm volume.
7. **Counters:** list with add, rename, delete, reorder.
8. **Advanced:** feature availability report (Brightness API ✓/✗, Keyboard API ✓/✗, Spotify permission, Notifications permission), debug geometry overlay, reset all settings, open data folder.

---

## 11. Persistence

Folder: `~/Library/Application Support/FontaDynamicNotch/`

| File | Content | Write policy |
|---|---|---|
| `settings.json` | `AppSettings` (Codable, versioned with `schemaVersion`) | debounced 0.5 s after change |
| `themes/*.json` | one file per user theme | on save |
| `state.json` | timers (length, run state, starred), selected timer, stopwatch, counters, last selected tool | debounced 0.5 s + on quit + on sleep |
| `sounds/` | imported alarm sounds | on import |

Decoding must tolerate missing keys (defaults), so adding settings later never wipes the user's config.

---

## 12. Performance budget

- **Idle (closed, nothing playing):** ~0% CPU. Only event monitors and notification observers are active; no timers.
- **Closed + music playing:** bars at ≤ 30 fps only while visible; closed time at 1 Hz.
- **Open:** progress interpolation and stopwatch at ≤ 30 Hz.
- Memory: aim for < 100 MB [Guess]. Artwork cache capped (§5.1).
- Verify with Instruments (Time Profiler, Allocations, Energy) in M10.

**MouseTracker:** `NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged])` plus a local monitor. Global mouse-moved monitoring does not require Accessibility permission [Likely]; verify in M0. Fallback: poll `NSEvent.mouseLocation` at 20 Hz.

---

## 13. Private APIs (isolated, feature-flagged)

These may break with a macOS update. Each one is wrapped so that a failure only removes its button.

| Feature | Mechanism | Confidence |
|---|---|---|
| Built-in display brightness | `dlopen` `/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices`; `DisplayServicesGetBrightness(CGDirectDisplayID, *Float)` / `DisplayServicesSetBrightness(CGDirectDisplayID, Float)` on the display where `CGDisplayIsBuiltin` is true | [Likely] |
| Keyboard backlight | `CoreBrightness.framework`, class `KeyboardBrightnessClient` (`copyKeyboardBacklightIDs`, `brightnessForKeyboard:`, `setBrightness:forKeyboard:`) via the Objective-C runtime | [Likely] |

Brightness sliders must also follow changes made with the keyboard keys: re-read the value when the slider appears, no polling.

---

## 14. Permissions summary

| Permission | When asked | If denied |
|---|---|---|
| Automation → Spotify | first Spotify script | media area shows "Allow Spotify control" |
| Notifications | first time a fallback notification is needed (or at first launch from Settings) | alarm still rings; missed-timer notices are lost |
| None for mouse tracking, CoreAudio, AirDrop, Trash | — | — |

---

## 15. Milestones

Each milestone ends with a build the user runs, plus a short checklist of what to test, in plain language.

- **M0 – Setup & risk checks.** Install XcodeGen, generate the project, signing with the Personal Team, git init. Small test harness (debug menu) that checks on macOS 27.2.1: (a) display brightness get/set, (b) keyboard backlight get/set, (c) Spotify AppleScript read/control + PlaybackStateChanged notification + whether repeat is boolean, (d) global mouse-moved monitor without extra permission, (e) panel hidden in full-screen Spaces without `.fullScreenAuxiliary`. **Report results to the user before continuing.**
- **M1 – Notch window & geometry.** Panel per screen, real/fake notch, debug overlay, hot-plug, lid-closed detection, full-screen hiding, click-through.
- **M2 – Hover & shape.** Notch shape with top fillets, closed↔open springs, 0.1 s hover delay, instant close, the close-blocking rules from §4.2, shadow.
- **M3 – Spotify.** SpotifyService, Home tab media UI, closed wings (cover + bars), dominant-color background (no notch fade).
- **M4 – Audio.** Volume slider, mute, output-device dropdown, listeners.
- **M5 – Brightness.** Screen + keyboard hover-to-slider controls, feature flags, per-screen/lid rules.
- **M6 – Timers & alarm.** 5 presets, chips, start/pause/reset, concurrent timers, alarm sound and auto-open, persistence and reboot rules, closed-state time priority.
- **M7 – Stopwatch & counters.** Laps, hover lap list, multiple counters, persistence.
- **M8 – Files tab.** Drag-to-open, shelf, drag-out, AirDrop, Trash.
- **M9 – Settings window.** All sections in §10, themes with JSON import/export, module reorder, launch at login, live apply.
- **M10 – Polish & performance.** Instruments pass, edge cases below, app icon.

---

## 16. Edge cases checklist

- Spotify closed / opened / quit while the notch is open; ads; podcasts; local files without artwork.
- Track change while dragging the progress slider.
- Screen connected/disconnected while open; lid closed while an alarm is ringing; display scaling changed.
- Sleep/wake with running timers and stopwatch; system clock or time-zone change.
- Timer ending while the length is being edited or a chip is clicked; two timers ending in the same second.
- Mission Control / Space switching; Stage Manager; "Automatically hide menu bar" enabled.
- Very long song/artist names; very long timer/counter names.
- Dragging a folder or many files to the Trash zone; files on read-only/network volumes.
- AirDrop with nobody nearby.
- Output device with no volume control; Bluetooth device disconnecting while selected.
- Private APIs unavailable → buttons removed and layout reflowed.
