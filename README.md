# SwiftDenon

Tiny SwiftUI remote for Denon/Marantz receivers (iOS + macOS).

- Power, volume, mute, inputs, zones 2/3, sound mode, tone, sub, dynamic EQ, sleep timer
- Live state: the receiver pushes updates over its control port (23), no polling
- Bonjour discovery or manual IP; macOS menu bar controller; Shortcuts actions
- `Packages/ReceiverKit` holds the brand-agnostic `Receiver` protocol and the Denon driver

## Build
    brew install xcodegen
    xcodegen generate
    open SwiftDenon.xcodeproj      # set your signing team
    (cd Packages/ReceiverKit && swift test)

Enable "Network control" on the receiver (Settings > Network > Control) if it won't connect.
