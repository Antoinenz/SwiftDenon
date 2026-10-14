# SwiftDenon

A small, modern SwiftUI remote for Denon / Marantz network receivers. Built for macOS 26+ (Liquid Glass) with an iOS target from the same code.

- Power, volume, mute, input and zones (Main, Zone 2/3), with optimistic UI
- Input names and visibility pulled from the receiver (hidden inputs stay hidden)
- Sound mode, dynamic EQ, bass / treble / sub faders, sleep timer
- Automatic discovery and connection: no IP entry needed
- Local zone names, optional 0.5 half-step volume, link to the receiver's web interface
- macOS menu bar controller and Shortcuts actions
- Brand-agnostic `Receiver` protocol; only Denon/Marantz is implemented so far

Status: personal project, tested against an AVR-X2700H.

## Build and run

    brew install xcodegen
    xcodegen generate                      # creates SwiftDenon.xcodeproj from project.yml
    open SwiftDenon.xcodeproj              # set your signing team, run the SwiftDenon scheme
    (cd Packages/ReceiverKit && swift test)

Command-line build without signing:

    xcodebuild -project SwiftDenon.xcodeproj -scheme SwiftDenon \
      -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

Enable network control on the receiver if it won't connect (Settings > Network > Control). On first launch macOS asks for Local Network permission; allow it, since discovery and control both need it.

## Documentation

| Doc | What's in it |
| --- | --- |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Package/app layout, data flow, optimistic updates, window sizing |
| [docs/DENON_PROTOCOL.md](docs/DENON_PROTOCOL.md) | Commands used, quirks learned from real hardware |
| [docs/DESIGN.md](docs/DESIGN.md) | UI principles and the reasoning behind each design decision |
| [docs/TESTING.md](docs/TESTING.md) | Unit tests, fake receiver, debug launch flags, screenshot workflow |
| [docs/DEVELOPMENT_LOG.md](docs/DEVELOPMENT_LOG.md) | Full chronological history of how the app was built, incl. requests and decisions |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Known gaps and ideas |

## Repository layout

    Packages/ReceiverKit/   Receiver protocol, Denon driver, discovery (pure Swift, unit tested)
    App/                    SwiftUI app (macOS + iOS)
    tools/fake_avr.py       Fake receiver for UI testing
    project.yml             XcodeGen project spec
    docs/                   Documentation

## License

To be added.
