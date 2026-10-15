#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Slider detents: trackpad haptics on Mac, Taptic Engine on iPhone. On the Mac, buttons rely on the
/// trackpad's own click; on iPhone `tap()` gives them a soft knock.
@MainActor
enum Haptics {
    static func tick() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #else
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// A soft knock for buttons on iPhone; the Mac's trackpad already clicks.
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}
