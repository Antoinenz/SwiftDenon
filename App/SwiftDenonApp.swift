import SwiftUI

@main
struct SwiftDenonApp: App {
    static let remoteWindowID = "remote"
    @State private var store: ReceiverStore
    #if os(macOS)
    @State private var menuBarIcon: MenuBarIconModel
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    #endif

    init() {
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
            Image(nsImage: menuBarIcon.image)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
