import SwiftUI
import ReceiverKit

/// Current input as a glass pill; tap to pick another from the receiver's enabled inputs.
struct InputPicker: View {
    @Environment(ReceiverStore.self) private var store

    var body: some View {
        let inputs = store.state.inputs
        let current = store.zone.input
        let name = inputs.first { $0.id == current }?.name ?? current.map(DenonProtocol.defaultName(for:)) ?? "Input"

        Menu {
            ForEach(inputs) { input in
                Button { store.setInput(input.id) } label: {
                    if input.id == current { Label(input.name, systemImage: "checkmark") } else { Text(input.name) }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(name).font(.headline).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .contentShape(.capsule)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
