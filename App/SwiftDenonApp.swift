import SwiftUI

@main
struct SwiftDenonApp: App {
    static let remoteWindowID = "remote"
    @State private var store: ReceiverStore
    #if os(macOS)
    @State private var menuBarIcon: MenuBarIconModel
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("hideMenuBarWhenAway") private var hideMenuBarWhenAway = false
    #endif

    init() {
        // Half steps are on unless the user turned them off (the receiver still decides per zone).
        UserDefaults.standard.register(defaults: ["halfStepVolume": true])
        let store = ReceiverStore()
        _store = State(initialValue: store)
        #if os(macOS)
        _menuBarIcon = State(initialValue: MenuBarIconModel(store: store))
        #endif
    }

    var body: some Scene {
        WindowGroup(id: Self.remoteWindowID) {
            RemoteView()
                .environment(store)
                .task { store.start(); store.watchNetwork() }
                #if DEBUG
                .preferredColorScheme(UserDefaults.standard.bool(forKey: "debugLight") ? .light : nil)   // `-debugLight YES`
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 380, height: 300)
        .windowResizability(.contentMinSize)
        #endif

        #if os(macOS)
        Settings {
            SettingsView().environment(store)
        }

        // Read here so the scene updates when the receiver appears or goes away.
        let inserted = showInMenuBar && (!hideMenuBarWhenAway || menuBarIcon.reachable)
        // The setter is deliberately empty: SwiftUI reports `false` whenever the item is hidden,
        // including when we hide it for being away, and writing that back would overwrite the
        // user's "Show in menu bar" preference.
        MenuBarExtra(isInserted: Binding(get: { inserted }, set: { _ in })) {
            MenuBarView().environment(store)
        } label: {
            Image(nsImage: menuBarIcon.image)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
