import SwiftUI
import ReceiverKit

struct RemoteView: View {
    @Environment(ReceiverStore.self) private var store
    @State private var showSettings = false

    var body: some View {
        let zone = store.zone

        VStack(spacing: 28) {
            header
            if !store.state.connected {
                connecting
            } else if !zone.power {
                standby(zone)
            } else {
                playing(zone)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 380)
        .animation(.snappy, value: zone.power)
        .animation(.snappy, value: store.state.connected)
        .containerBackground(.ultraThinMaterial, for: .window)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { step(1); return .handled }
        .onKeyPress(.downArrow) { step(-1); return .handled }
        .onKeyPress(.space) { store.toggleMute(); return .handled }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var header: some View {
        HStack {
            if store.state.zones.count > 1 { ZonePicker() }
            Spacer()
            GlassCircleButton(symbol: "gearshape", size: 36) { showSettings = true }
        }
    }

    private var connecting: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(store.host.isEmpty ? "Looking for your receiver…" : "Connecting…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func standby(_ zone: Zone) -> some View {
        VStack(spacing: 20) {
            GlassCircleButton(symbol: "power", size: 96) { store.setPower(true) }
            Text(store.state.zones.count > 1 ? zone.name : store.displayName)
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func playing(_ zone: Zone) -> some View {
        VStack(spacing: 28) {
            Text(zone.volume.formatted(.number.precision(.fractionLength(0...1))))
                .font(.system(size: 84, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: zone.volume))
                .opacity(zone.mute ? 0.3 : 1)
            GlassSlider(
                value: Binding(get: { zone.volume }, set: { store.setVolume($0) }),
                range: 0...zone.maxVolume, dimmed: zone.mute,
                onEnd: { store.setVolume(zone.volume, final: true) }
            )
            InputChips()
            GlassEffectContainer(spacing: 14) {
                HStack(spacing: 14) {
                    GlassCircleButton(symbol: zone.mute ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                      active: zone.mute, tint: .orange, size: 44) { store.toggleMute() }
                    GlassCircleButton(symbol: "power", size: 44) { store.setPower(false) }
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func step(_ delta: Double) {
        let z = store.zone
        guard z.power else { return }
        store.setVolume(min(z.maxVolume, max(0, z.volume + delta)), final: true)
    }
}
