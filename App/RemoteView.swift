import SwiftUI
import ReceiverKit

struct RemoteView: View {
    @Environment(ReceiverStore.self) private var store
    @State private var showSettings = false
    @AppStorage("arrowKeysSwitchZones") private var arrowKeysSwitchZones = false
    @AppStorage("hideVolumeSlider") private var hideVolumeSlider = false
    private enum Kind: Hashable { case connecting, standby, playing }
    /// Natural height per state view. Each view only writes its own entry, so a view that is
    /// fading out can't overwrite the height of the one fading in.
    @State private var heights: [Kind: CGFloat] = [:]
    private let defaultHeights: [Kind: CGFloat] = [.connecting: 200, .standby: 178, .playing: 380]

    private let edge: CGFloat = 40            // gap above and below standby content
    @State private var toolbarHeight: CGFloat = 0

    var body: some View {
        let zone = store.zone
        let isPlaying = store.state.connected && zonePower(zone)
        let kind: Kind = !store.state.connected ? .connecting : (isPlaying ? .playing : .standby)

        // The content is an overlay so it never imposes a minimum window height;
        // WindowHeightAnimator owns the window height and animates it both ways.
        Color.clear
            .frame(width: 380)
            .frame(minHeight: 100, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { toolbarHeight = $0 }
            .overlay(alignment: .top) {
                Group {
                    if !store.state.connected {
                        connecting
                    } else if !zonePower(zone) {
                        standby(zone)
                    } else {
                        playing(zone)
                    }
                }
                .padding(.horizontal, 24)
                .frame(width: 380)
                .animation(.smooth(duration: 0.35), value: isPlaying)
            }
        #if os(macOS)
        .background(WindowHeightAnimator(height: heights[kind] ?? defaultHeights[kind] ?? 300))
        #endif
        .containerBackground(.ultraThinMaterial, for: .window)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Keep the slot filled so the gear stays on the right when there is no picker.
                if store.state.zones.count > 1 { ZonePicker() } else { Color.clear.frame(width: 200, height: 1) }
            }
            .sharedBackgroundVisibility(store.state.zones.count > 1 ? .automatic : .hidden)
            ToolbarItem(placement: .primaryAction) {
                GlassCircleButton(symbol: "gearshape", size: 12, iconSize: 15) { showSettings = true }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { store.stepVolume(by: 1); return .handled }
        .onKeyPress(.downArrow) { store.stepVolume(by: -1); return .handled }
        .onKeyPress(.space) { store.toggleMute(); return .handled }
        .onKeyPress("m") { store.toggleMute(); return .handled }
        .onKeyPress("p") { store.togglePower(); return .handled }
        // ←/→ and Tab swap roles when "Arrow keys switch zones" is on.
        .onKeyPress(.leftArrow) { arrowKeysSwitchZones ? store.cycleZone(by: -1) : store.cycleInput(by: -1); return .handled }
        .onKeyPress(.rightArrow) { arrowKeysSwitchZones ? store.cycleZone(by: 1) : store.cycleInput(by: 1); return .handled }
        .onKeyPress(.tab) { arrowKeysSwitchZones ? store.cycleInput(by: 1) : store.cycleZone(by: 1); return .handled }
        .onKeyPress(characters: .init(charactersIn: "123")) { press in
            store.selectZone(at: Int(press.characters)! - 1)
            return .handled
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var connecting: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(store.host.isEmpty ? "Looking for your receiver…" : "Connecting…")
                .foregroundStyle(.secondary)
        }
        // Centred in the whole window, not just below the toolbar: the extra bottom
        // padding matches the toolbar's height.
        .padding(.top, 36)
        .padding(.bottom, 36 + toolbarHeight)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[.connecting] = $0 }
    }

    private func standby(_ zone: Zone) -> some View {
        VStack(spacing: 16) {
            GlassCircleButton(symbol: "power", size: 96) { store.setPower(true) }
            let label = store.state.zones.count > 1 ? store.name(of: zone) : store.displayName
            Text(label)
                .font(.callout)
                .foregroundStyle(Color.primary.opacity(0.55))   // not .secondary: vibrancy goes dark during the blur transition
                .id(label)
                .transition(.blurReplace)
        }
        .padding(.vertical, edge)
        .animation(.snappy, value: store.zoneID)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[.standby] = $0 }
        .transition(.opacity)
    }

    private func playing(_ zone: Zone) -> some View {
        VStack(spacing: 26) {
            if hideVolumeSlider {
                // No slider: − and + sit either side of the number.
                HStack(spacing: 20) {
                    GlassCircleButton(symbol: "minus", size: 40) { store.stepVolume(by: -1) }
                        .opacity(zone.mute ? 0.35 : 1)
                    volumeNumber(zone).frame(minWidth: 150)
                    GlassCircleButton(symbol: "plus", size: 40) { store.stepVolume(by: 1) }
                        .opacity(zone.mute ? 0.35 : 1)
                }
                .animation(.smooth(duration: 0.3), value: zone.mute)
                .padding(.top, 22)
                .padding(.bottom, 4)
            } else {
                volumeNumber(zone)
                    .padding(.top, 22)
                    .padding(.bottom, 10)
                HStack(spacing: 12) {
                    GlassCircleButton(symbol: "minus", size: 40) { store.stepVolume(by: -1) }
                    GlassSlider(
                        value: Binding(get: { zone.volume }, set: { store.setVolume($0) }),
                        range: 0...zone.maxVolume, halfStep: store.useHalfSteps,
                        onEnd: { store.setVolume(zone.volume, final: true) }
                    )
                    GlassCircleButton(symbol: "plus", size: 40) { store.stepVolume(by: 1) }
                }
                .opacity(zone.mute ? 0.35 : 1)
                .animation(.smooth(duration: 0.3), value: zone.mute)
            }
            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 16) {
                    GlassCircleButton(symbol: "power", active: true, tint: .green) { store.setPower(false) }
                    GlassCircleButton(symbol: zone.mute ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                      active: zone.mute, tint: .orange) { store.toggleMute() }
                }
            }
            InputPicker()
        }
        .padding(.bottom, 24)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[.playing] = $0 }
        .animation(.snappy, value: store.zoneID)
        .transition(.opacity)
    }

    private func volumeNumber(_ zone: Zone) -> some View {
        Text(zone.volume.formatted(.number.precision(store.useHalfSteps ? .fractionLength(1) : .fractionLength(0...1))))
            .font(.system(size: 84, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText(value: zone.volume))
            .animation(.snappy(duration: 0.25), value: zone.volume)
            .opacity(zone.mute ? 0.3 : 1)
            .animation(.smooth(duration: 0.3), value: zone.mute)
    }

    private func zonePower(_ zone: Zone) -> Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugStandby") { return false }   // `-debugStandby YES` for layout checks
        #endif
        return zone.power
    }
}
