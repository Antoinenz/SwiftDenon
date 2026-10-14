import SwiftUI
import ReceiverKit

struct InputChips: View {
    @Environment(ReceiverStore.self) private var store

    var body: some View {
        let current = store.zone.input
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.inputs) { input in
                    let selected = input.id == current
                    Button(input.name) { store.setInput(input.id) }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .capsule)
                        .foregroundStyle(selected ? .white : .primary)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}
