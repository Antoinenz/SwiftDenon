import SwiftUI
import ReceiverKit

/// Current input as a native glass button (same material as the other buttons);
/// opens a popover with the receiver's enabled inputs.
struct InputPicker: View {
    @Environment(ReceiverStore.self) private var store
    @State private var open = false

    var body: some View {
        let inputs = store.state.inputs
        let current = store.zone.input
        let name = inputs.first { $0.id == current }?.name ?? current.map(DenonProtocol.defaultName(for:)) ?? "Input"

        Button { open.toggle() } label: {
            HStack(spacing: 8) {
                Text(name).font(.headline).lineLimit(1)
                    .id(name)
                    .transition(.blurReplace)
                Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .animation(.snappy, value: name)
        .popover(isPresented: $open) {
            VStack(spacing: 2) {
                ForEach(inputs) { input in
                    InputRow(name: input.name, selected: input.id == current) {
                        store.setInput(input.id)
                        open = false
                    }
                }
            }
            .padding(6)
            .frame(minWidth: 210)
        }
    }
}

private struct InputRow: View {
    let name: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(name)
                Spacer(minLength: 16)
                if selected { Image(systemName: "checkmark").font(.caption.weight(.semibold)) }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(hovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
        .onHover { hovering = $0 }
    }
}
