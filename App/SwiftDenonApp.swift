import SwiftUI

@main
struct SwiftDenonApp: App {
    @State private var store = ReceiverStore()

    var body: some Scene {
        WindowGroup {
            RemoteView()
                .environment(store)
                .task { store.start() }
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif

        #if os(macOS)
        MenuBarExtra("SwiftDenon", systemImage: "hifispeaker.2.fill") {
            MenuBarView().environment(store)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
