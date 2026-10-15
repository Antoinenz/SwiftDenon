import SwiftUI

@main
struct SwiftDenonApp: App {
    static let remoteWindowID = "remote"
    static let settingsWindowID = "settings"
    @State private var store: ReceiverStore
    #if os(macOS)
    @State private var menuBarIcon: MenuBarIconModel
    @State private var menuBarMenu: MenuBarContextMenu
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
        _menuBarMenu = State(initialValue: MenuBarContextMenu(store: store))
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
        // A plain Window rather than the Settings scene: that one lays its toolbar out on a second
        // row under the traffic lights, while a Window gets the same single-row bar as the remote.
        Window("Settings", id: Self.settingsWindowID) {
            SettingsView().environment(store)
        }
        .windowResizability(.contentSize)
        .commands { SettingsCommand() }

        // Read here so the scene updates when the receiver appears or goes away.
        let inserted = showInMenuBar && (!hideMenuBarWhenAway || menuBarIcon.reachable)
        // The setter is deliberately empty: SwiftUI reports `false` whenever the item is hidden,
        // including when we hide it for being away, and writing that back would overwrite the
        // user's "Show in menu bar" preference.
        MenuBarExtra(isInserted: Binding(get: { inserted }, set: { _ in })) {
            MenuBarView().environment(store)
        } label: {
            MenuBarLabel(icon: menuBarIcon, menu: menuBarMenu)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

#if os(macOS)
/// Puts "Settings…" (⌘,) in the app menu, where the Settings scene would have.
private struct SettingsCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { openWindow(id: SwiftDenonApp.settingsWindowID) }
                .keyboardShortcut(",")
        }
    }
}
#endif
