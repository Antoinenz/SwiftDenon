import SwiftUI

@main
struct SwiftDenonApp: App {
    @State private var store = ReceiverStore()

    var body: some Scene {
        WindowGroup {
            RemoteView()
                .environment(store)
                .task { store.start() }
                #if DEBUG
                .preferredColorScheme(UserDefaults.standard.bool(forKey: "debugLight") ? .light : nil)   // `-debugLight YES`
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 380, height: 300)
        .windowResizability(.contentMinSize)
        #endif

        #if os(macOS)
        MenuBarExtra("SwiftDenon", systemImage: "hifispeaker.2.fill") {
            MenuBarView().environment(store)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
