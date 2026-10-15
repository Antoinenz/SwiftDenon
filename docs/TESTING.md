# Testing

## Unit tests

    cd Packages/ReceiverKit && swift test

- `DenonProtocolTests`: volume parse/format, command encoding, status decoding, zone independence, friendly names / hidden sources, half-step learning, zone sleep line not treated as input.
- `DenonReceiverTests`: runs `DenonReceiver` against an in-process `NWListener` fake AVR (push on connect, command written, refresh query sent).

## Demo mode

Settings → General → Demo mode runs the whole app against `DemoReceiver`, an in-memory receiver. Nothing goes over the network and the saved host is untouched. For a one-off run without saving the setting, launch with `--args -demoMode YES`.

## Wire log

Every line sent to and received from a Denon receiver is logged. Stream it while reproducing a bug:

    /usr/bin/log stream --level debug --predicate 'subsystem == "dev.antoine.SwiftDenon"'

(In zsh, `log` is a shell builtin, so use the full path.)

## Fake receiver for UI testing

`tools/fake_avr.py` impersonates a receiver so you can test without touching your amp (no sudden volume):

    python3 tools/fake_avr.py --power-cycle        # toggles main-zone power every 2 s
    python3 tools/fake_avr.py --mute-cycle         # toggles mute every 2 s
    defaults write dev.antoine.SwiftDenon host "127.0.0.1:2323"

Restore your real address afterwards (`defaults write dev.antoine.SwiftDenon host "<your amp ip>"` or Settings).

## Debug launch arguments (DEBUG builds only)

| Argument | Effect |
| --- | --- |
| `-zone 2` | Start with Zone 2 selected |
| `-debugStandby YES` | Force the standby screen (layout checks without powering zones) |
| `-debugLight YES` | Force light appearance |
| `-debugSettings YES` | iPhone: open the settings sheet at launch |
| `-debugPage Amp\|Zones\|General` | Settings: start on that page |

Pass with `open build/Build/Products/Debug/SwiftDenon.app --args -zone 2`.

## Screenshot workflow used during development

- Find the app's window id with `CGWindowListCopyWindowInfo` and capture with `screencapture -x -o -l <id> out.png`.
- Animation checks: poll the window bounds at ~8 ms from another process and print height changes (showed that growing jumped while shrinking animated), or capture a burst of frames and compare luminance regions (used to confirm the mute fade and that label text never goes darker than the background during a transition).
- Settings is its own window: open it with the gear (or `click` at window position + (354, 26)) and capture the topmost window, which `shot.sh` does, since the settings window is listed before the remote.
- Right-click needs a real event too: post `rightMouseDown`/`rightMouseUp` `CGEvent`s at the icon (the same position).
- Menu bar panel: it only opens for a real click, not an Accessibility `click`, so post a `CGEvent` mouse down/up on the item's position (`get position of menu bar item 1 of menu bar 2`). The panel is the app's window at layer 101.
- "Away from home" for the menu bar: run the fake receiver, launch the app with `-demoMode NO -host 127.0.0.1:2323 -hideMenuBarWhenAway YES`, then kill the fake. The icon should disappear after about 10 s and come back after restarting it. Don't pass `-showInMenuBar`: a launch argument overrides the stored value and hid the bug this setting once had (the SwiftUI setter overwriting the preference).
- Scroll: `CGEvent(scrollWheelEvent2Source:…)` posted at the window with the pointer over the number works when the setting is on (`-scrollChangesVolume YES`). Pixel units exercise the trackpad path, line units the mouse-wheel path.
- Animation of the slider thumb: a burst of window screenshots (`screencapture -l`, ~100 ms apart) is enough to see an overshoot; a screen *recording* of the window repeated stale frames and gave a false "no animation" reading. To tell whether an animation is applied at all, temporarily make it `.linear(duration: 1.5)`.
- iPhone: build with `-destination 'generic/platform=iOS Simulator' -derivedDataPath build-ios`, `xcrun simctl boot <iPhone>`, `simctl install booted …/Debug-iphonesimulator/SwiftDenon.app`, then `simctl launch --terminate-running-process booted dev.antoine.SwiftDenon -demoMode YES` and `simctl io booted screenshot out.png`. A fresh launch takes a while: a screenshot after a few seconds is a black launch screen. `simctl ui booted appearance dark|light` switches appearance. Debug launch arguments: `-zone 2` (demo zone 2 is off, so this shows standby), `-hideVolumeSlider YES`, `-debugSettings YES`, `-debugPage General|Zones|Amp`. `simctl` cannot tap, and the simulator isn't an on-screen window when booted this way, so use these arguments instead of clicking.
- Stale window frames: SwiftUI stores a frame per scene type in the app's defaults (`NSWindow Frame …`); delete those keys to test a fresh launch.

## App icon previews

Render the icon without opening Icon Composer:

    "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" App/AppIcon.icon \
      --export-image --output-file out.png --platform macOS --rendition Default --width 512 --height 512 --scale 1

Use `--rendition Dark` for dark mode.

## Manual checklist

- Launch with no saved host: it finds and connects to the receiver.
- Toggle Main off: Zone 2 must stay on.
- Switch zones on/off: window resizes smoothly both ways, top bar doesn't move.
- Mute: button tints, icon swaps, number/slider/± fade.
- Slider: smooth thumb, whole numbers; half-step setting on: slow = .5, fast = whole.
- Input popover: names match the amp, hidden inputs absent, capsule hover highlight.
- Long zone names (12 chars) fit the toolbar.
- Arrow keys switch zones on: ←/→ switch zones, Tab cycles inputs.
- Hide volume slider on: − number + in one row, all fade when muted.
- Keyboard: ←/→ cycle inputs (wrapping, ignored when the zone is off), P toggles power, M/Space mute, 1/2/3 and Tab switch zones.
- Disconnected (try `-host 127.0.0.1:2399`) or single zone: gear stays top right, no zone picker and no empty glass pill.
- Scroll to change volume on: scrolling over the number or slider changes it in the window and the menu bar; off, nothing happens. Up is louder.
- Hide when away on: icon disappears ~10 s after the receiver goes away and returns when it is back; *Show in menu bar* stays on in Settings throughout.
- iPhone slider: tap anywhere on the track quickly, then hold: the volume never changes on touch alone, only when the finger moves; after a fast flick the receiver ends on the value shown (the old bug sent the previous volume back after a quick tap).
- iCloud (needs a paid team and the entitlement): rename a zone on one device and see it on another within a minute or so.
- iPhone, on a device (not yet done): volume buttons change the amp one step per press and hold-to-repeat works; the phone's own volume is back where it was after leaving the app or turning the setting off; no system volume overlay appears; with the amp off the buttons control the phone as usual; backgrounding for a while and coming back reconnects; swiping sideways changes zone; the local-network prompt appears on first launch.
- Right-click (or control-click) the menu bar icon: Open, Settings…, Mute/Unmute, Turn On/Off, Quit. Mute and Turn Off act on the selected zone; Settings opens the window; left-click still opens the panel afterwards.
- Volume number: crossing 9↔10 (or 99.5↔100) slides the digits and recentres rather than jumping, in the window and the menu bar.
- Slider: clicking the track far from the thumb makes the thumb bounce over to the cursor; dragging after that follows the pointer without lag.
- Menu bar: zone switcher, volume, mute, power and input all mirror the window; standby shows one power button; icon dial follows the volume and eases rather than jumps; ring when off, slash when muted; *Open SwiftDenon* reopens a closed window; *Show in menu bar* off removes it.
- Settings opens as a window with a native glass switcher; pages switch; demo mode toggles without touching the saved host.
