import SwiftUI

struct ZonePicker: View {
    @Environment(ReceiverStore.self) private var store
    @Namespace private var ns

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(store.state.zones) { z in
                    let selected = z.id == store.zoneID
                    Button(z.name) { withAnimation(.snappy) { store.zoneID = z.id } }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .glassEffect(selected ? .regular.tint(.accentColor.opacity(0.5)).interactive() : .regular.interactive(),
                                     in: .capsule)
                        .glassEffectID(z.id, in: ns)
                }
            }
        }
    }
}
