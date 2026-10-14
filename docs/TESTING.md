# Testing

## Unit tests

    cd Packages/ReceiverKit && swift test

- `DenonProtocolTests`: volume parse/format, command encoding, status decoding, zone independence, friendly names / hidden sources, half-step learning, zone sleep line not treated as input.
- `DenonReceiverTests`: runs `DenonReceiver` against an in-process `NWListener` fake AVR (push on connect, command written, refresh query sent).

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

Pass with `open build/Build/Products/Debug/SwiftDenon.app --args -zone 2`.

## Screenshot workflow used during development

- Find the app's window id with `CGWindowListCopyWindowInfo` and capture with `screencapture -x -o -l <id> out.png`.
- Animation checks: poll the window bounds at ~8 ms from another process and print height changes (showed that growing jumped while shrinking animated), or capture a burst of frames and compare luminance regions (used to confirm the mute fade and that label text never goes darker than the background during a transition).
- Stale window frames: SwiftUI stores a frame per scene type in the app's defaults (`NSWindow Frame …`); delete those keys to test a fresh launch.

## Manual checklist

- Launch with no saved host: it finds and connects to the receiver.
- Toggle Main off: Zone 2 must stay on.
- Switch zones on/off: window resizes smoothly both ways, top bar doesn't move.
- Mute: button tints, icon swaps, number/slider/± fade.
- Slider: smooth thumb, whole numbers; half-step setting on: slow = .5, fast = whole.
- Input popover: names match the amp, hidden inputs absent, capsule hover highlight.
- Long zone names (12 chars) fit the toolbar.
