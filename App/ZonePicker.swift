import SwiftUI

/// Native segmented control; the toolbar supplies the glass.
struct ZonePicker: View {
    @Environment(ReceiverStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Picker("Zone", selection: $store.zoneID) {
            ForEach(store.state.zones) { Text($0.name).tag($0.id) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}
