#if os(macOS)
import SwiftUI

struct MenuBarView: View {
    @Environment(ReceiverStore.self) private var store

    var body: some View {
        let zone = store.zone
        VStack(spacing: 12) {
            HStack {
                Text(zone.volume.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .opacity(zone.mute ? 0.3 : 1)
                Spacer()
                Button { store.toggleMute() } label: {
                    Image(systemName: zone.mute ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                Button { store.setPower(!zone.power) } label: {
                    Image(systemName: "power").foregroundStyle(zone.power ? Color.accentColor : .secondary)
                }
            }
            .buttonStyle(.plain)
            .font(.title3)
            Slider(
                value: Binding(get: { zone.volume }, set: { store.setVolume($0) }),
                in: 0...zone.maxVolume, step: 0.5,
                onEditingChanged: { if !$0 { store.setVolume(zone.volume, final: true) } }
            )
            Picker("Input", selection: Binding(get: { zone.input ?? "" }, set: { store.setInput($0) })) {
                ForEach(store.inputs) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
        }
        .padding(16)
        .frame(width: 280)
    }
}
#endif
