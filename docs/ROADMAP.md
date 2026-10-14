# Roadmap and known gaps

- iOS: the build currently fails (`RemoteView` uses the macOS-only `.window` container background and `.windowToolbar` placement without an `#if os(macOS)` guard). After that, the layout needs a real pass on iPhone; it was designed and screenshot-tested on macOS only.
- An intermittent self-mute while dragging the volume slider was reported once and couldn't be reproduced; the wire log is in place to catch it.
- Control Center / widget controls (App Intents exist for Shortcuts only).
- HTTP fallback for receivers without telnet control.
- Zone names from the amp if a readable endpoint is found (currently local names).
- Second brand driver (Yamaha YXC HTTP/JSON, Onkyo eISCP) behind the existing `Receiver` protocol.
- Sound mode list per model (currently a generic Denon list).
- Surround/channel levels and Audyssey settings.
- Signing and notarisation.
