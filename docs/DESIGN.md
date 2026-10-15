# Design

## Principles

1. **Almost nothing on screen.** Show only what's relevant to the current state: a powered-off zone shows one big power button; a powered-on zone shows volume, slider, power/mute and the input.
2. **Native first.** Use the system's glass button styles, segmented control, toolbar and popover so hover, press and focus come for free. Custom glass only where no system control exists (slider thumb, EQ faders).
3. **Optimistic and calm.** Changes appear instantly and never flicker back.
4. **Mac-first.** Window chrome, toolbar and trackpad behaviour are designed for macOS 26. The iPhone app reuses the same controls (`GlassCircleButton`, `GlassSlider`, `VolumeReadout`, `InputPicker`) in its own layout.

## Layout (iPhone)

- One screen, portrait. The zone switcher (the same glass switcher as the menu bar: equal-width segments, a lens while pressed) and a glass gear sit in the navigation bar; there is no title. The native segmented control was tried first and padded its labels unevenly.
- The slider is relative: it never jumps to where the finger lands, and moves exactly with it.
- Behind it a soft `MeshGradient` in blues, dark or light to match the system, because glass over flat black or white has nothing to bend. Deliberately quiet.
- Playing: the number at 112 pt in the middle, then `−` slider `+`, then, in the thumb's reach, power and mute at 80 pt and the input pill. Standby is one 120 pt power button and the zone's name. Connecting is a spinner, with no zone switcher.
- With *Hide volume slider* on, `−` number `+` is one row at 76 pt.
- Buttons give a soft haptic knock (the Mac's trackpad clicks for itself); slider detents and volume-button steps use the selection tick.
- Swipe sideways anywhere that isn't a control to change zone.
- Volume buttons: see ARCHITECTURE. The number is the feedback, so the system volume overlay is suppressed.

## Layout (macOS)

- Frosted window (`containerBackground(.ultraThinMaterial, for: .window)`), 380 pt wide, native toolbar with the zone selector (segmented control, centred with the traffic lights) and a glass gear button at the trailing edge.
- Playing: large rounded volume number, `−` slider `+`, power and mute glass buttons, and the current input as a glass pill that opens a popover list of the receiver's enabled inputs.
- Standby: large power button and zone name, with equal 40 pt gaps above and below.
- Menu bar: a 300 pt panel. A zone switcher on top, built to match the toolbar's (glass track, equal-width segments, soft sliding thumb) because a popover has no toolbar to supply the real one. Then `−` number `+` (no slider; the window's sliderless layout), then one row with the input pill on the left and mute and power on the right, and *Open SwiftDenon* as a full-width glass button. There is no Quit in the panel: it lives in the menu you get by right-clicking the icon, with Open, Settings…, Mute and Power.

## Decisions and why

- **Inputs as a dropdown, not chips.** A chip grid crowded the window. A glass button + popover matches the other buttons (a `Menu` drew its own flat bezel under the glass). Popover rows use a capsule highlight to match the popover's large corner radius.
- **−/+ buttons stay.** An early version removed them; they are useful on a trackpad, and the keyboard covers everything: ↑/↓ volume, ←/→ input, Space or M mute, P power, 1/2/3 or Tab zones. Plain keys rather than ⌘ shortcuts, handled with `onKeyPress` on the main view only, so they never fire while typing in Settings.
- **Volume number animates** with `contentTransition(.numericText)`; the animation must be attached directly to the number (a view-wide animation was removed by mistake once).
- **Whole-number volume by default.** Half steps are opt-in and only for zones that support them. Even when enabled, fast slider drags snap to whole numbers (speed threshold ≈ 350 pt/s) so the number stays readable; the thumb itself follows the pointer smoothly and only the reported value snaps.
- **Haptics: slider detents on the Mac, plus soft knocks on buttons on iPhone.** On the Mac the press itself is silent (it would double the trackpad's own click); detents tick as the value crosses whole numbers while dragging, and while scrolling over the volume; the trackpad already clicks for buttons. Detents use `NSHapticFeedbackManager`. On iPhone nothing clicks for you, so buttons get a soft impact (`Haptics.tap`) and detents and volume-button steps use the selection tick.
- **Mute is a tint, not a style swap.** Switching between `.glass` and `.glassProminent` can't animate; one `.glass` style with an animated `.tint` can. The icon uses `.symbolEffect(.replace)`. While muted, the number, slider and ± fade to ~30 %.
- **Labels use an explicit translucent colour instead of `.secondary`.** `.secondary` is a vibrancy style and turned dark during a `blurReplace` transition.
- **Zone names cap at 12 characters** so the segmented control fits the toolbar between the traffic lights and the gear; longer names collapsed the toolbar into an overflow menu.
- **Window height is animated manually**, both directions, because SwiftUI/AppKit resizing jumped (see ARCHITECTURE.md).
- **No manual IP by default.** The app scans the subnet and connects. A manual address (optionally `host:port`) remains in Settings for odd networks.
- **The menu bar icon is the app icon, and it carries state.** The dial's indicator and lit ticks follow the volume; a ring means off or disconnected, a slash means muted. A glance at the menu bar answers "is it on, and how loud?". Drawn as a template image so the system tints it; dots are slightly larger than in the app icon so they survive at 18 pt.
- **EQ as faders.** The amp only exposes bass, treble and sub, so those are drawn as three vertical glass faders rather than a pretend multi-band EQ.

## Reference apps

Searches found no strong direct references. The design follows Apple's Liquid Glass guidance (glass for the control layer, `GlassEffectContainer`, native button styles, toolbar glass) and the macOS Tahoe menu bar's transparent, expand-in-place feel. VolumeGlass (a minimal volume overlay) was the closest comparable.

## App icon

`App/AppIcon.icon` is an Icon Composer document (open it in Icon Composer, which ships inside Xcode). A white volume knob with a blue indicator at about 70%, ringed by eleven scale dots: lit up to the indicator, faint after it. Three glass groups give Liquid Glass depth: indicator on top, knob in the middle, scale at the back. Each shape is a 1024x1024 SVG in `Assets/`, so layers line up without positioning. Previews can be rendered with `ictool` (`Icon Composer.app/Contents/Executables/ictool`).
