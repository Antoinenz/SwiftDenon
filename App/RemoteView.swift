import SwiftUI
import ReceiverKit

struct RemoteView: View {
    @Environment(ReceiverStore.self) private var store
    @State private var showSettings = false
    @State private var showMore = false

    var body: some View {
        let zone = store.zone

        VStack(spacing: 26) {
            header
            VStack(spacing: 2) {
                Text(zone.volume.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.system(size: 84, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: zone.volume))
                    .opacity(zone.mute ? 0.3 : 1)
                Text(store.state.connected ? zone.name : "Connecting…")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            HStack(spacing: 12) {
                GlassCircleButton(symbol: "minus", size: 40) { step(-1) }
                GlassSlider(
                    value: Binding(get: { zone.volume }, set: { store.setVolume($0) }),
                    range: 0...zone.maxVolume, dimmed: zone.mute,
                    onEnd: { store.setVolume(zone.volume, final: true) }
                )
                GlassCircleButton(symbol: "plus", size: 40) { step(1) }
            }

            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 16) {
                    GlassCircleButton(symbol: "power", active: zone.power, tint: .green) { store.setPower(!zone.power) }
                    GlassCircleButton(symbol: zone.mute ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                      active: zone.mute, tint: .orange) { store.toggleMute() }
                }
            }

            InputChips()
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 400)
        .animation(.snappy, value: zone)
        .containerBackground(.ultraThinMaterial, for: .window)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { step(1); return .handled }
        .onKeyPress(.downArrow) { step(-1); return .handled }
        .onKeyPress(.space) { store.toggleMute(); return .handled }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showMore) { MoreSheet() }
        .onAppear { if store.host.isEmpty { showSettings = true } }
    }

    private func step(_ delta: Double) {
        let z = store.zone
        store.setVolume(min(z.maxVolume, max(0, z.volume + delta)), final: true)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(store.state.connected ? .green : .orange)
                .frame(width: 8, height: 8)
            if store.state.zones.count > 1 { ZonePicker() }
            Spacer()
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    GlassCircleButton(symbol: "slider.horizontal.3", size: 36) { showMore = true }
                        .disabled(!store.state.connected)
                    GlassCircleButton(symbol: "gearshape", size: 36) { showSettings = true }
                }
            }
        }
    }
}
