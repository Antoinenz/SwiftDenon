#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Slider detents only: trackpad haptics on Mac, Taptic Engine on iPhone. Buttons rely on the trackpad's own click.
@MainActor
enum Haptics {
    static func tick() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #else
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
