import SwiftUI

/// The zone switcher. On the Mac it is the native segmented control and the toolbar supplies the
/// glass. On iPhone the native one doesn't pad its labels evenly, so it uses the same glass
/// switcher as the menu bar: equal-width segments, and a glass lens while pressed.
struct ZonePicker: View {
    @Environment(ReceiverStore.self) private var store

    var body: some View {
        @Bindable var store = store
        #if os(iOS)
        GlassSegmented(selection: $store.zoneID, options: store.state.zones.map(\.id), fontSize: 15, height: 34) { id in
            Text(store.state.zone(id).map(store.name(of:)) ?? "Zone")
        }
        #else
        Picker("Zone", selection: $store.zoneID) {
            ForEach(store.state.zones) { Text(store.name(of: $0)).tag($0.id) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 200)
        #endif
    }
}
