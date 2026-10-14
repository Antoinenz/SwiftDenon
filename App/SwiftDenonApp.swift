import SwiftUI

@main
struct SwiftDenonApp: App {
    static let remoteWindowID = "remote"
    @State private var store = ReceiverStore()
    #if os(macOS)
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    #endif

    var body: some Scene {
        WindowGroup(id: Self.remoteWindowID) {
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
        MenuBarExtra(isInserted: $showInMenuBar) {
            MenuBarView().environment(store)
        } label: {
            Image(systemName: menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    #if os(macOS)
    /// Filled while the zone is playing, outlined when it's off or disconnected, crossed out when muted.
    private var menuBarSymbol: String {
        let zone = store.zone
        guard store.state.connected, zone.power else { return "hifispeaker.2" }
        return zone.mute ? "speaker.slash.fill" : "hifispeaker.2.fill"
    }
    #endif
}
