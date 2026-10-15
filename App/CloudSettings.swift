import Foundation

/// Keeps chosen settings the same on every device signed in to the user's iCloud, by mirroring
/// them between `UserDefaults` and iCloud's key-value store. Only property-list values and only
/// the keys below are synced; everything else stays on the device (the receiver address, the
/// volume-button and scroll behaviours, window frames).
///
/// To sync another setting, add its `UserDefaults` key to `syncedKeys` and make whatever reads it
/// reload on `.cloudSettingsDidChange` (see `ReceiverStore.reloadZoneNames`). Settings held in
/// `@AppStorage` need nothing more: they already read `UserDefaults` live.
///
/// This does nothing until the app is signed with the iCloud key-value storage entitlement
/// (`Config/SwiftDenon.entitlements`), which a free Personal Team can't have. Without it the store
/// silently stores nothing, and the app behaves as it did before.
@MainActor final class CloudSettings {
    /// Planned next: per-zone volume slider limits (a lowest and highest value), so a loud zone can
    /// be capped on every device.
    static let syncedKeys = ["zoneNames"]

    private let cloud = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                               object: cloud, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.pull() }
            },
            center.addObserver(forName: UserDefaults.didChangeNotification,
                               object: defaults, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.push() }
            },
        ]
        cloud.synchronize()
        pull()   // what is already in iCloud wins over this device's copy
        push()   // anything only this device has goes up
    }

    /// iCloud to this device.
    private func pull() {
        var changed = false
        for key in Self.syncedKeys {
            guard let remote = cloud.object(forKey: key), !Self.equal(remote, defaults.object(forKey: key)) else { continue }
            defaults.set(remote, forKey: key)
            changed = true
        }
        if changed { NotificationCenter.default.post(name: .cloudSettingsDidChange, object: nil) }
    }

    /// This device to iCloud.
    private func push() {
        for key in Self.syncedKeys {
            guard let local = defaults.object(forKey: key), !Self.equal(local, cloud.object(forKey: key)) else { continue }
            cloud.set(local, forKey: key)
        }
    }

    private static func equal(_ a: Any?, _ b: Any?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return (a as AnyObject).isEqual(b)
    }
}

extension Notification.Name {
    /// Posted after iCloud changed a synced setting on this device.
    static let cloudSettingsDidChange = Notification.Name("SwiftDenonCloudSettingsDidChange")
}
