import SwiftUI
import ReceiverKit

struct RemoteView: View {
    @Environment(ReceiverStore.self) private var store
    @State private var showSettings = false
    @State private var showMore = false

    var body: some View {
        @Bindable var store = store
        let zone = store.zone

        VStack(spacing: 28) {
            header
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Text(zone.volume.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.system(size: 88, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: zone.volume))
                    .opacity(zone.mute ? 0.3 : 1)
                Text(zone.name).font(.callout).foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(get: { zone.volume }, set: { store.setVolume($0) }),
                in: 0...zone.maxVolume, step: 0.5,
                onEditingChanged: { if !$0 { store.setVolume(zone.volume, final: true) } }
            )
            HStack(spacing: 20) {
                round("power", on: zone.power) { store.setPower(!zone.power) }
                round(zone.mute ? "speaker.slash.fill" : "speaker.wave.2.fill", on: zone.mute) { store.toggleMute() }
            }
            InputChips()
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: 440)
        .frame(minWidth: 340, minHeight: 560)
        .animation(.snappy, value: zone)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showMore) { MoreSheet() }
        .onAppear { if store.host.isEmpty { showSettings = true } }
    }

    private var header: some View {
        HStack {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(store.state.connected ? .green : .orange)
            if store.state.zones.count > 1 { ZonePicker() }
            Spacer()
            Button { showMore = true } label: { Image(systemName: "slider.horizontal.3") }
                .disabled(!store.state.connected)
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
        }
        .buttonStyle(.plain)
        .font(.title3)
    }

    private func round(_ symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 64, height: 64)
                .background(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .circle)
                .foregroundStyle(on ? .white : .primary)
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .sensoryFeedback(.impact, trigger: on)
        #endif
    }
}
