#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Trackpad haptics on Mac, Taptic Engine on iPhone.
@MainActor
enum Haptics {
    static func tap() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #else
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func tick() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #else
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
