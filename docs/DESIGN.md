# Design

## Principles

1. **Almost nothing on screen.** Show only what's relevant to the current state: a powered-off zone shows one big power button; a powered-on zone shows volume, slider, power/mute and the input.
2. **Native first.** Use the system's glass button styles, segmented control, toolbar and popover so hover, press and focus come for free. Custom glass only where no system control exists (slider thumb, EQ faders).
3. **Optimistic and calm.** Changes appear instantly and never flicker back.
4. **Mac-first.** Window chrome, toolbar and trackpad behaviour are designed for macOS 26; iOS shares the code.

## Layout (macOS)

- Frosted window (`containerBackground(.ultraThinMaterial, for: .window)`), 380 pt wide, native toolbar with the zone selector (segmented control, centred with the traffic lights) and a glass gear button at the trailing edge.
- Playing: large rounded volume number, `−` slider `+`, power and mute glass buttons, and the current input as a glass pill that opens a popover list of the receiver's enabled inputs.
- Standby: large power button and zone name, with equal 40 pt gaps above and below.

## Decisions and why

- **Inputs as a dropdown, not chips.** A chip grid crowded the window. A glass button + popover matches the other buttons (a `Menu` drew its own flat bezel under the glass). Popover rows use a capsule highlight to match the popover's large corner radius.
- **−/+ buttons stay.** An early version removed them; they are useful on a trackpad, and arrow keys also work (↑/↓ volume, Space mute).
- **Volume number animates** with `contentTransition(.numericText)`; the animation must be attached directly to the number (a view-wide animation was removed by mistake once).
- **Whole-number volume by default.** Half steps are opt-in and only for zones that support them. Even when enabled, fast slider drags snap to whole numbers (speed threshold ≈ 350 pt/s) so the number stays readable; the thumb itself follows the pointer smoothly and only the reported value snaps.
- **Haptics only on sliders.** The trackpad already clicks for buttons. Slider detents use `NSHapticFeedbackManager` (`UIFeedbackGenerator` on iOS).
- **Mute is a tint, not a style swap.** Switching between `.glass` and `.glassProminent` can't animate; one `.glass` style with an animated `.tint` can. The icon uses `.symbolEffect(.replace)`. While muted, the number, slider and ± fade to ~30 %.
- **Labels use an explicit translucent colour instead of `.secondary`.** `.secondary` is a vibrancy style and turned dark during a `blurReplace` transition.
- **Zone names cap at 12 characters** so the segmented control fits the toolbar between the traffic lights and the gear; longer names collapsed the toolbar into an overflow menu.
- **Window height is animated manually**, both directions, because SwiftUI/AppKit resizing jumped (see ARCHITECTURE.md).
- **No manual IP by default.** The app scans the subnet and connects. A manual address (optionally `host:port`) remains in Settings for odd networks.
- **EQ as faders.** The amp only exposes bass, treble and sub, so those are drawn as three vertical glass faders rather than a pretend multi-band EQ.

## Reference apps

Searches found no strong direct references. The design follows Apple's Liquid Glass guidance (glass for the control layer, `GlassEffectContainer`, native button styles, toolbar glass) and the macOS Tahoe menu bar's transparent, expand-in-place feel. VolumeGlass (a minimal volume overlay) was the closest comparable.

## App icon

`App/AppIcon.icon` is an Icon Composer document (open it in Icon Composer, which ships inside Xcode). A white volume knob with a blue indicator at about 70%, ringed by eleven scale dots: lit up to the indicator, faint after it. Three glass groups give Liquid Glass depth: indicator on top, knob in the middle, scale at the back. Each shape is a 1024x1024 SVG in `Assets/`, so layers line up without positioning. Previews can be rendered with `ictool` (`Icon Composer.app/Contents/Executables/ictool`).
