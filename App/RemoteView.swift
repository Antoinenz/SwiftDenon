import SwiftUI
import ReceiverKit

struct RemoteView: View {
    @Environment(ReceiverStore.self) private var store
    @State private var showSettings = false
    private enum Kind: Hashable { case connecting, standby, playing }
    /// Natural height per state view. Each view only writes its own entry, so a view that is
    /// fading out can't overwrite the height of the one fading in.
    @State private var heights: [Kind: CGFloat] = [:]
    private let defaultHeights: [Kind: CGFloat] = [.connecting: 200, .standby: 178, .playing: 380]

    private let edge: CGFloat = 24            // gap above and below standby content

    var body: some View {
        let zone = store.zone
        let isPlaying = store.state.connected && zonePower(zone)
        let kind: Kind = !store.state.connected ? .connecting : (isPlaying ? .playing : .standby)

        // The content is an overlay so it never imposes a minimum window height;
        // WindowHeightAnimator owns the window height and animates it both ways.
        Color.clear
            .frame(width: 380)
            .frame(minHeight: 100, maxHeight: .infinity)
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
                if store.state.zones.count > 1 { ZonePicker() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Settings", systemImage: "gearshape") { showSettings = true }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { step(1); return .handled }
        .onKeyPress(.downArrow) { step(-1); return .handled }
        .onKeyPress(.space) { store.toggleMute(); return .handled }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var connecting: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(store.host.isEmpty ? "Looking for your receiver…" : "Connecting…")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[.connecting] = $0 }
    }

    private func standby(_ zone: Zone) -> some View {
        VStack(spacing: 16) {
            GlassCircleButton(symbol: "power", size: 96) { store.setPower(true) }
            Text(store.state.zones.count > 1 ? store.name(of: zone) : store.displayName)
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(.vertical, edge)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[.standby] = $0 }
        .transition(.opacity)
    }

    private func playing(_ zone: Zone) -> some View {
        VStack(spacing: 26) {
            Text(zone.volume.formatted(.number.precision(store.useHalfSteps ? .fractionLength(1) : .fractionLength(0...1))))
                .font(.system(size: 84, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: zone.volume))
                .animation(.snappy(duration: 0.25), value: zone.volume)
                .opacity(zone.mute ? 0.3 : 1)
                .padding(.top, 22)
                .padding(.bottom, 10)
            HStack(spacing: 12) {
                GlassCircleButton(symbol: "minus", size: 40) { step(-1) }
                GlassSlider(
                    value: Binding(get: { zone.volume }, set: { store.setVolume($0) }),
                    range: 0...zone.maxVolume, dimmed: zone.mute, halfStep: store.useHalfSteps,
                    onEnd: { store.setVolume(zone.volume, final: true) }
                )
                GlassCircleButton(symbol: "plus", size: 40) { step(1) }
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

    private func zonePower(_ zone: Zone) -> Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugStandby") { return false }   // `-debugStandby YES` for layout checks
        #endif
        return zone.power
    }

    private func step(_ delta: Double) {
        let z = store.zone
        guard z.power else { return }
        store.setVolume(min(z.maxVolume, max(0, z.volume + delta)), final: true)
    }
}
