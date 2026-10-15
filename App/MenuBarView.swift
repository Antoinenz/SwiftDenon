#if os(macOS)
import SwiftUI
import ReceiverKit

/// Compact controller for the selected zone, built from the same glass controls as the main window.
struct MenuBarView: View {
    @Environment(ReceiverStore.self) private var store

    var body: some View {
        let zone = store.zone
        let isPlaying = store.state.connected && zone.power
        VStack(spacing: 16) {
            header
            Group {
                if !store.state.connected {
                    connecting
                } else if !zone.power {
                    standby(zone)
                } else {
                    playing(zone)
                }
            }
            .transition(.opacity)
            openButton
        }
        .padding(16)
        .frame(width: 300)
        .animation(.smooth(duration: 0.3), value: isPlaying)
        .animation(.snappy, value: store.zoneID)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { store.stepVolume(by: 1); return .handled }
        .onKeyPress(.downArrow) { store.stepVolume(by: -1); return .handled }
        .onKeyPress(.space) { store.toggleMute(); return .handled }
        .onKeyPress("m") { store.toggleMute(); return .handled }
        .onKeyPress("p") { store.togglePower(); return .handled }
        .onKeyPress(.tab) { store.cycleZone(by: 1); return .handled }
    }

    @ViewBuilder private var header: some View {
        if store.state.connected, store.state.zones.count > 1 {
            GlassSegmented(selection: Binding(get: { store.zoneID }, set: { store.zoneID = $0 }),
                           options: store.state.zones.map(\.id)) { id in
                Text(store.state.zone(id).map(store.name(of:)) ?? "Zone").lineLimit(1)
            }
        } else {
            Text(store.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var connecting: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(store.host.isEmpty && !store.demoMode ? "Looking for your receiver…" : "Connecting…")
                .foregroundStyle(.secondary)
        }
        .frame(height: 64)
    }

    private func standby(_ zone: Zone) -> some View {
        VStack(spacing: 10) {
            GlassCircleButton(symbol: "power", size: 64) { store.setPower(true) }
            Text("Off").font(.callout).foregroundStyle(Color.primary.opacity(0.55))
        }
        .padding(.vertical, 4)
    }

    private func playing(_ zone: Zone) -> some View {
        VStack(spacing: 18) {
            // No slider here: − and + sit either side of the number, as in the window's sliderless layout.
            HStack(spacing: 16) {
                GlassCircleButton(symbol: "minus", size: 30) { store.stepVolume(by: -1) }
                    .opacity(zone.mute ? 0.35 : 1)
                VolumeReadout(volume: zone.volume, halfSteps: store.useHalfSteps, size: 44, muted: zone.mute)
                    .frame(minWidth: 110)
                    .scrollsVolume(store)
                GlassCircleButton(symbol: "plus", size: 30) { store.stepVolume(by: 1) }
                    .opacity(zone.mute ? 0.35 : 1)
            }
            // Source on the left, mute and power on the right.
            HStack(spacing: 10) {
                InputPicker()
                Spacer(minLength: 8)
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        GlassCircleButton(symbol: zone.mute ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                          active: zone.mute, tint: .orange, size: 34) { store.toggleMute() }
                        GlassCircleButton(symbol: "power", active: true, tint: .green, size: 34) { store.setPower(false) }
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: zone.mute)
    }

    private var openButton: some View {
        Button(action: AppWindows.showRemote) {
            Text("Open SwiftDenon")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
    }
}
#endif
