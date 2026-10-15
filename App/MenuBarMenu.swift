#if os(macOS)
import AppKit
import SwiftUI

/// Window actions shared by the menu bar panel and its right-click menu. SwiftUI only hands out
/// `openWindow` inside views, so the menu bar label registers it here when it appears.
@MainActor enum AppWindows {
    static var open: (String) -> Void = { _ in }

    /// Brings the remote window forward, or reopens it if it was closed.
    static func showRemote() {
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix(SwiftDenonApp.remoteWindowID) == true }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            open(SwiftDenonApp.remoteWindowID)
        }
    }

    static func showSettings() {
        NSApp.activate()
        open(SwiftDenonApp.settingsWindowID)
    }
}

/// The menu bar item's label. It exists as a view only so it can read `openWindow`.
struct MenuBarLabel: View {
    let icon: MenuBarIconModel
    let menu: MenuBarContextMenu
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: icon.image)
            .onAppear {
                AppWindows.open = { openWindow(id: $0) }
                menu.install()
            }
    }
}

/// Right-click (or control-click) on the menu bar icon. `MenuBarExtra` has no API for a second
/// menu, so this watches for the click on the status item's window and pops up an `NSMenu`.
@MainActor final class MenuBarContextMenu: NSObject {
    private let store: ReceiverStore
    private var monitor: Any?

    init(store: ReceiverStore) { self.store = store }

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
            guard let self, let window = event.window, window.className.contains("StatusBar"),
                  event.type == .rightMouseDown || event.modifierFlags.contains(.control) else { return event }
            MainActor.assumeIsolated { self.show(for: event, in: window) }
            return nil
        }
    }

    private func show(for event: NSEvent, in window: NSWindow) {
        guard let view = window.contentView else { return }
        let zone = store.zone
        let menu = NSMenu()
        menu.addItem(item("Open SwiftDenon", #selector(openRemote)))
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        if store.state.connected {
            menu.addItem(.separator())
            if zone.power {
                menu.addItem(item(zone.mute ? "Unmute" : "Mute", #selector(toggleMute)))
            }
            let name = store.state.zones.count > 1 ? " \(store.name(of: zone))" : ""
            menu.addItem(item(zone.power ? "Turn Off\(name)" : "Turn On\(name)", #selector(togglePower)))
        }
        menu.addItem(.separator())
        menu.addItem(item("Quit SwiftDenon", #selector(quit), key: "q"))
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openRemote() { AppWindows.showRemote() }
    @objc private func openSettings() { AppWindows.showSettings() }
    @objc private func toggleMute() { store.toggleMute() }
    @objc private func togglePower() { store.togglePower() }
    @objc private func quit() { NSApp.terminate(nil) }
}
#endif
