# Roadmap and known gaps

- iPhone: only run in the simulator so far. Not verified on a device: the volume-button capture (the simulator has no buttons), the reconnect after backgrounding, the sideways swipe between zones, and the local-network permission prompt. iPad isn't a target (the layout is a phone's).
- iPhone gestures (swipe up, scrubbing curve, hold-to-repeat timing) are tested in the simulator by `UITests/`, but their feel on a real finger is untested; the numbers are easy to tune (`scrubFactor`, the 380 ms / 150 ms / 50 ms repeat timings).
- An intermittent self-mute while dragging the volume slider was reported once and couldn't be reproduced; the wire log is in place to catch it.
- Control Center / Lock Screen / widget controls (App Intents exist for Shortcuts only). Needs a widget extension target.
- iCloud: zone names sync once the app is signed with the key-value entitlement (paid developer account); more local settings can join `CloudSettings.syncedKeys`, starting with per-zone volume slider limits. Untested across devices.
- HTTP fallback for receivers without telnet control.
- Zone names from the amp if a readable endpoint is found (currently local names).
- Second brand driver (Yamaha YXC HTTP/JSON, Onkyo eISCP) behind the existing `Receiver` protocol.
- Sound mode list per model (currently a generic Denon list).
- Surround/channel levels and Audyssey settings.
- Signing and notarisation.
