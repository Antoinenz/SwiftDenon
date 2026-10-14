# Architecture

## Overview

    ┌────────────────────────────── App (SwiftUI) ──────────────────────────────┐
    │ RemoteView ─ ZonePicker ─ InputPicker ─ SettingsView ─ MenuBarView         │
    │        │                                                                  │
    │   ReceiverStore (@Observable, @MainActor)                                 │
    │        │  optimistic "pending" overrides, zone names, discovery results   │
    └────────┼──────────────────────────────────────────────────────────────────┘
             │ Receiver protocol (Command in, AsyncStream<ReceiverState> out)
    ┌────────┴────────────── ReceiverKit (Swift package) ───────────────────────┐
    │ DenonReceiver (actor, NWConnection, port 23)                              │
    │ DemoReceiver (actor, in-memory receiver for demo mode)                    │
    │ DenonProtocol (pure encode/decode, unit tested)                           │
    │ Discovery (subnet probe for the control port)                             │
    └───────────────────────────────────────────────────────────────────────────┘

## ReceiverKit

- `Receiver` (protocol): `connect()`, `disconnect()`, `send(Command)`, `states: AsyncStream<ReceiverState>`. Anything brand-specific stays behind it; `inputs` and zones live in the state, not the protocol.
- `ReceiverState`: zones (`Zone`: power, volume, maxVolume, mute, input, `halfStep`), sound mode, bass/treble/sub, dynamic EQ, sleep minutes, `connected`, friendly name, and the receiver's source names / order / hidden set. `inputs` is derived: the enabled sources with the names configured on the amp.
- `Command`: brand-neutral enum (power, volume, step, mute, input, sound mode, tone, sub, dynamic EQ, sleep, refresh).
- `DenonProtocol`: `encode(Command) -> [String]` and `apply(line, to: &state)`. No I/O, so it is fully unit tested.
- `DenonReceiver`: actor over `NWConnection`. The receiver pushes status lines, so state is live without polling. Lines are split on `\r`. Commands are spaced 50 ms apart because AVRs drop faster input. Auto-reconnects with backoff (1s doubling to 10s). `.waiting` is treated as transient (Local Network permission can sit there) with a 15 s timeout.
- `DemoReceiver`: actor that keeps a simulated receiver in memory (two zones, five named inputs, sound mode, EQ, dynamic EQ, sleep) and applies every `Command` to it directly. Used by demo mode.
- Wire logging: `DenonReceiver` logs every line sent (`TX`) and received (`RX`) through `os.Logger` (subsystem `dev.antoine.SwiftDenon`, category `wire`).
- `Discovery.scan()`: enumerates the local /24 from `getifaddrs`, probes every host on port 23 in parallel, sends `PW?` + `NSFRN ?`, and accepts hosts that answer like an AVR (`PW`/`ZM`/`MV` lines). Reports the friendly name. No Bonjour name guessing.

## App

- `ReceiverStore` owns the connection, saved host (`UserDefaults`), local zone names, discovery results and web-UI availability. `start()` connects to the saved host, or scans and connects to the first receiver found. If the saved host fails three times it rescans (DHCP changes). Hosts may be `address` or `address:port`. With demo mode on (`demoMode` in `UserDefaults`), `start()` uses a `DemoReceiver` instead and leaves the saved host untouched.
- **Optimistic updates**: every setter calls `hold(key, matches:, apply:)`, which applies the change to local state immediately and registers a pending override. Incoming states pass through `reconcile`, which re-applies any override until the receiver confirms it (`matches`) or a timeout passes (1–1.5 s, 4 s for power). This prevents stale status lines from flickering the UI back.
- **Volume**: `setVolume` rounds to whole numbers unless the zone supports half steps and the user enabled "Half-step volume". Sends are throttled to ~10/s; the final value is always sent.
- **Views**: `RemoteView` shows one of three states: connecting, standby (single large power button) or playing (volume, slider, ±, power/mute, input). `GlassControls.swift` has the glass button, the volume slider (thumb follows the pointer; the reported value snaps, and fast drags skip half steps) and the vertical EQ slider.
- **Settings**: one sheet. A sheet on macOS shows no toolbar items in its top bar, so the bar is built by hand and laid out like the main window's toolbar: `GlassSegmented` centred (a glass capsule with a glass selection lens that slides between pages) and a round glass-prominent checkmark Done on the right. It is attached with `safeAreaBar` plus `.scrollEdgeEffectStyle(.hard, for: .top)` so content scrolling under it is blurred behind a toolbar-style backdrop (`safeAreaInset` gives no backdrop, and the default soft edge effect is barely visible on macOS). Three pages:
  - **Amp**: receiver connection (switching, search, manual address, web-interface link), sound mode, dynamic EQ, sleep timer, EQ faders.
  - **Zones**: local zone names.
  - **General**: half-step volume, hide volume slider (− / + then sit either side of the number), arrow keys switch zones (swaps ←/→ and Tab), demo mode, version.
- **Toolbar**: the principal slot always holds something (the zone picker, or a clear 200 pt spacer with its glass background hidden) so the gear stays on the right when there is only one zone or no connection.
- **Shortcuts**: `Intents.swift` opens a short-lived connection to the saved receiver for power, volume, mute and input.

## Window sizing (macOS)

SwiftUI resizes windows instantly and imposes the content's minimum height, so height is owned by `WindowHeightAnimator`:

1. The content is laid out as an `overlay` of a flexible clear view, so it never constrains the window.
2. Each state view measures its own natural height (`onGeometryChange`) into a per-state dictionary. Per-state entries matter: a single shared value let a fading-out view overwrite the incoming view's height and clip the window.
3. The animator steps the frame with a timer (120 Hz, 0.35 s ease-in-out), top edge fixed, same easing in both directions. NSWindow's built-in animation was unreliable when shrinking.
4. The window is non-resizable and the zoom button is disabled; the default size is 380 pt wide so a fresh launch isn't 900 pt wide.

## Targets

macOS 26 / iOS 26 (Liquid Glass APIs). The Xcode project is generated by XcodeGen from `project.yml` and is gitignored. `project.yml` declares the `SwiftDenon` scheme explicitly (XcodeGen stopped generating it implicitly).

## App icon

`App/AppIcon.icon` is an Icon Composer document added as a resource (`wrapper.icon`), with `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`. Xcode compiles it into `AppIcon.icns` and `Assets.car`. If the Dock or Finder keeps showing the old icon after a build, that is the icon cache: re-register the app with `lsregister -f` and restart the Dock.
