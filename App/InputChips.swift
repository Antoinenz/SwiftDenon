import SwiftUI
import ReceiverKit

struct InputChips: View {
    @Environment(ReceiverStore.self) private var store

    var body: some View {
        let current = store.zone.input
        GlassEffectContainer(spacing: 8) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(store.state.inputs) { input in
                    let selected = input.id == current
                    Button { Haptics.tap(); store.setInput(input.id) } label: {
                        Text(input.name)
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(selected ? .regular.tint(.accentColor.opacity(0.55)).interactive() : .regular.interactive(),
                                 in: .capsule)
                }
            }
        }
    }
}
