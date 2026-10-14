# Development log

A chronological record of how SwiftDenon was built in conversation with Claude Code: what was asked (the user's words quoted), what was decided, what went wrong and how it was fixed. Commit history in git mirrors this in small steps.

Conventions requested by the user: git repo with many small commits per feature, agent-related files gitignored, no "co-authored" trailers in commits.

---

## 1. Brief and plan

> "plan a modern, super simple app to connect to my denon reciever (and others), control volume, inputs and zones. add support for all useful features, while keeping the ui extremely lightweight and modern"

Decisions (via questions): **iOS + macOS** from one SwiftUI codebase; **Denon/Marantz first with a pluggable protocol layer** for other brands.

Plan: SwiftUI multiplatform; a Swift package (`ReceiverKit`) with a brand-neutral `Receiver` protocol and a Denon driver over the telnet-style control port (23); `NWConnection`; live state from pushed status lines; discovery; one-screen UI; zone switcher; sound/tone sheet; menu bar extra; App Intents. The package was named `ReceiverKit` rather than `AVKit` to avoid clashing with Apple's framework.

## 2. Foundations

- Git init, `.gitignore` (agent files ignored, generated Xcode project ignored).
- `ReceiverKit`: `ReceiverState`, `Command`, `Receiver`, `DenonProtocol` (encode/decode, volume `MV505` = 50.5), `DenonReceiver` actor with reconnect, and tests including an in-process fake AVR.
- XcodeGen project (`project.yml`), `ReceiverStore`, `RemoteView`, zone picker, input chips, settings, "More" sheet (sound mode, tone, dynamic EQ, sleep).
- Bonjour discovery, macOS menu bar controller, Shortcuts intents.

## 3. First run on real hardware

User: *"i entered my reciever ip but didnt connect"* and *"read the latest apple swift ui desgin docs. i want it to be a modern transparent ui. focus on the mac app."*

- Verified the amp worked from the command line (`nc`, then a small Swift probe using the driver), so the bug was in the app: `.waiting` connection states were being cancelled, which breaks while Local Network permission is pending. Fixed (waiting is transient, 15 s timeout).
- Read Apple's Liquid Glass docs; rebuilt the UI with `glassEffect`, `GlassEffectContainer`, glass button styles, frosted window; raised deployment target to macOS/iOS 26.

## 4. Simplification pass

User: *"make the ui even more simple. search up reference mac apps. haptic feedback, auto search + connect to amp without manual ip input. the inputs should pull the friendly names from the amp, and hide the ones that are supposed to be hidden. things like the 'tone' could even be transformed into an eq. the ui needs to be even less crowded, like not displaying the inputs and volume when the zone is turned off for example. the settings pages merged together, and a button to open the amps webui if available"*

- Discovered the amp exposes `SSFUN` (names) and `SSSOD` (USE/DEL = hidden); web UI answers on port 80.
- Auto discovery rewritten: probe the local /24 for port 23 and verify an AVR-style reply (Bonjour name guessing was unreliable).
- Standby/connecting states, single merged settings sheet, bass/treble/sub as vertical glass faders, web-UI button, haptics.
- Reference app search found only Apple's Liquid Glass menu bar and VolumeGlass.

## 5. Screenshot-driven iteration

User: *"take screenshots of the ui and make improvement from there. i actually prefered the -+ icons on either side of the slider, and the position of the mute+power buttons, the input selector needs to be some sort of dropdown or something though. also why remove the text animation from the main volume? make sure the zone being controlled actually supports .5 volume, as some zones dont have that. and ... when the volume is being slided fast enough, skip the .5, only go through .5 at slower speeds"*

- Added a screenshot workflow (window id + `screencapture`).
- Restored −/+ and mute/power row; input chips became a dropdown; volume number animation restored.
- Per-zone `halfStep` learned from the digit count of reports; velocity-aware slider snapping.
- Screenshots exposed a bug: Zone 2's input showed "SLPOFF" (sleep line parsed as input). Fixed with a whitelist of source codes.

## 6. Smoothness, toolbar and haptics

User: *"make the slider smooth too, and actually remove the .5 completely by default, maybe just make it a setting. also, you shouldve noticed the large gap at the top of the window. could you try placing the zone selectors at the top of the window in the center sort of aligned with the window controls along with the settings icon all the way in the top right. also make sure when switching between zones of different height, the top bar doesnt move, and the bottom of the window resized smoothly. also remove hapic feedback from anything but the sliders"*

- Slider thumb follows the pointer continuously; only the value snaps. Half-step volume became a Settings toggle (off by default).
- Zone picker and settings moved into the native toolbar (segmented control); hidden title bar replaced by the toolbar approach.
- Haptics limited to sliders.

## 7. Optimism and spacing

User: *"the ui needs to be more optimistic ... sometimes it flickers when selecting different options. the vertical padding top and bottom ... of the volume display is a little small too. when switching between zones ... the input selector used to have an animation ... re add it."*

- Added the pending-override system (`hold` / `reconcile`) so optimistic changes persist until confirmed.
- Volume display padding; input name blur-replace animation.

## 8. Zone power bug and zone names

User: *"make sure to fetch the friendly zone names ... it looks like when i toggle a zone, its controlling both zones"*

- Root cause: Main "off" was sent as `PWSTANDBY` (whole unit). Switched to `ZMOFF`/`ZMON`; `PWON` no longer implies main on; `PWSTANDBY` clears all zones.
- Zone names: investigated telnet queries, port 8080 goform/XML and `AppCommand.xml`; nothing returned names (403/empty). Agreed fallback: user-editable local zone names in Settings.

## 9. Native buttons and window animation

User: *"vertical spacing for the power button still not equal when zone is off. make sure all the buttons are proper macos 27 swift ui buttons that react to clicks and hovers as they should. the window doesnt smoothing resize when switching between zones of different height ..."*

- Round buttons moved to native `.buttonStyle(.glass)` / `.glassProminent`.
- Window resize moved to an AppKit-driven animator; per-state measured heights.

## 10. Long names and one-way animation

User reported the toolbar overflowing with long zone names, the window only animating one direction, and wanted `.0` shown with half steps.

- Names capped at 12 characters, picker max width.
- Sampling the window height from a separate process showed shrink animated but grow jumped (SwiftUI forced the larger minimum before the animation). Fixed by laying content out as an overlay so it never sets a minimum, and animating manually both ways.
- With half-step on, the volume always shows one decimal.

## 11. Clipped window

User screenshot: window stuck at the standby height while powered on. Cause: one shared height value could be overwritten by a fading-out view. Fixed with per-state height entries; verified with a fake receiver that toggled power. `host:port` addresses added so the app could talk to the fake receiver.

## 12. Dropdown colour, spacing, label animation

User: *"fix the colour of the input dropdown to be the same as the rest of the buttons ... add more vertical spacing top and bottom to the power button when off ... animate the zone name text transition under the button"*

- Reproduced in light mode: `Menu` draws its own bezel under the glass. Replaced with a glass button + popover.
- Standby edge 24 → 40 pt; zone label `blurReplace` transition.
- Found and fixed a 900 pt default window width on fresh launch (explicit default size).

## 13. Popover rounding and dark label

User: *"fix the rounded (or more the lack of) of the option selector ... the text colour goes to a dark color while the transition happens"*

- Popover row highlight changed to a capsule with more padding.
- `.secondary` (vibrancy) turned dark during the blur transition; replaced with an explicit translucent colour. Verified with a 30-frame burst (no frame darker than the background).

## 14. Mute animation, fade, gear button

User: *"the mute button ... has no animations at all. the button and its icon need an animation, and all the other volume controls/data need to fade to more transparent ... make sure the settings icon in the top right is a proper swift ui button that reacts to hover and clicks like the others too"*

- One `.glass` style with an animated `.tint`; symbol-replace icon transition.
- Number, slider and ± fade when muted.
- Gear is the same glass button inside the toolbar (shared background hidden, size tuned to match).

## 15. Publishing

User: *"push to github ... add documentation ... add all of our chat history and details into doc files that are not gitignored"* — this documentation set was added and the repository pushed. Licence and repository name are to be decided later.

## 16. iOS status and scheme

User: *"pull latest changes, and let me know where we're at for the ios app"*

- Only the user's MIT `LICENSE` came in.
- `xcodegen` stopped generating the scheme, so it is now declared in `project.yml`.
- The iOS build fails on two macOS-only modifiers in `RemoteView`; the iPhone layout has never been checked. Left for later, Mac first.

## 17. Self-mute while sliding

User: *"looks like theres a bug where when im using the volume slider it mutes by itself"*

- No code path sends a mute from the slider; mute comes only from the button and the Space key.
- Added wire logging (`os.Logger`, `TX`/`RX` lines) to catch it. The user then reported it had stopped; not reproduced.

## 18. Settings pages and demo mode

User: *"seperate the settings tab into sections, like one for zones, one for the amp, and the last general app settings"*, then *"add a button in the app settings to toggle demo mode"*

- Settings got Amp / Zones / General pages behind a segmented switcher. The switcher sits above the form because a sheet's principal toolbar item isn't shown on macOS, and inside the form it rendered as a narrow card.
- `DemoReceiver` (in-memory) and a Demo mode toggle under General. The saved host is left alone.

## 19. Gear position

User: *"the settings icon moves to the left when disconnected. make sure it stays on the right side"*

- With no zone picker the principal toolbar slot was empty and the gear slid left. It now holds a clear spacer with its glass background hidden (otherwise a blank pill appeared).

## 20. App icon

User: *"design an icon"*, then *"not a massive fan, it needs to fit the apple icon design. also please build the icon composer for me to open"*

- First attempt: flat SVGs of a dial arc. Rejected.
- Second: an Icon Composer document (`App/AppIcon.icon`): white glass knob with a blue indicator, eleven scale dots lit up to it, blue gradient; three groups for Liquid Glass depth. Previewed with `ictool` in light and dark. Approved: *"ah very nice. i like that. add it to the app"*.
- Added to the target. The Dock still showed the old icon until the icon cache was refreshed (`lsregister -f`, restart Dock).

## 21. README

User: *"rewrite the readme to follow this template"* (the user's Claudeometer and battery-tray READMEs): centred logo, title and tagline, features, installation, usage, how it works, development, screenshots, licence.

## 22. Connecting state and keyboard shortcuts

User: *"please center loading vertically in the window"*, then *"a few more keyboard shortcuts, like a key to turn on and off a zone, maybe even switch between inputs and zones"*

- The connecting view is centred in the whole window: its bottom padding includes the toolbar height.
- Keys: ←/→ inputs, P power, M mute (Space still works), 1/2/3 zones, Tab next zone. Checked against the fake receiver with the wire log.

## 23. Selector positions, settings header, two new settings

User asked whether to swap the zone and input selectors. Recommendation: keep them. The zone picker scopes the whole window and lives in the toolbar, which never moves; at the bottom it would jump as the window resizes between standby and playing, and an input picker would be meaningless while a zone is off.

User: *"make sure the top bar is a modern swift ui liquid glass component too. theres also an akward gap to the left of the settigns window title. add an app setting to invert the zone selector and input selctor keybinds, and a setting that disabled the volume slider, and aligns the -+ volume buttons horizontally on either side of the volume display"*

- Settings header rebuilt by hand: title aligned with the section headers, glass-prominent Done, and a glass segmented control (`GlassSegmented`). The native segmented picker inside a glass capsule drew a double outline.
- *Arrow keys switch zones* swaps ←/→ and Tab. *Hide volume slider* moves − and + beside the number.

---

## Testing notes that shaped the work

- A real amp was available on the LAN; destructive or loud actions (powering zones, changing volume) were avoided, using `tools/fake_avr.py` instead. Early on the user's saved address was briefly overwritten for fake-receiver tests and restored each time.
- A test accidentally wiped the user's saved zone names once; names are now truncated on load rather than cleared.
- Debug launch arguments (`-zone`, `-debugStandby`, `-debugLight`) exist in DEBUG builds only; see TESTING.md.

## Open items

See ROADMAP.md. Notably: the iOS build is broken and its layout unverified, zone names can't be read from the amp, and only Denon/Marantz is implemented.
