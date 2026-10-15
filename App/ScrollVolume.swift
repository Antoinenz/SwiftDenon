import SwiftUI

extension View {
    /// Lets the scroll wheel or a two-finger swipe over this view change the volume, when the
    /// "Scroll to change volume" setting is on. macOS only; elsewhere it does nothing.
    func scrollsVolume(_ store: ReceiverStore) -> some View {
        modifier(ScrollVolume(store: store))
    }
}

private struct ScrollVolume: ViewModifier {
    let store: ReceiverStore
    @AppStorage("scrollChangesVolume") private var enabled = false

    func body(content: Content) -> some View {
        #if os(macOS)
        content.background(ScrollCatcher(enabled: enabled) { steps, final in
            store.scrollVolume(by: steps, final: final)
        })
        #else
        content
        #endif
    }
}

#if os(macOS)
import AppKit

/// SwiftUI has no scroll-wheel modifier on macOS, so this watches scroll events and acts on the
/// ones that land inside its bounds. It sits behind the content and never blocks clicks.
private struct ScrollCatcher: NSViewRepresentable {
    let enabled: Bool
    let onScroll: @MainActor (_ steps: Double, _ final: Bool) -> Void

    func makeNSView(context: Context) -> CatcherView { CatcherView() }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.enabled = enabled
        view.onScroll = onScroll
    }

    static func dismantleNSView(_ view: CatcherView, coordinator: ()) { view.stopMonitoring() }

    final class CatcherView: NSView {
        var enabled = false
        var onScroll: @MainActor (Double, Bool) -> Void = { _, _ in }
        private var monitor: Any?
        private var accumulated: CGFloat = 0
        /// Trackpad points of travel per volume step.
        private let pointsPerStep: CGFloat = 8

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self else { return event }
                let consumed = MainActor.assumeIsolated { self.handle(event) }
                return consumed ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        /// Returns true when the event was ours and should not travel further.
        private func handle(_ event: NSEvent) -> Bool {
            guard enabled, let window, event.window === window,
                  bounds.contains(convert(event.locationInWindow, from: nil)) else { return false }
            // Coasting after the fingers lift would keep changing the volume; swallow it.
            guard event.momentumPhase.isEmpty else { return true }

            // Up (or toward the right) is louder, whichever way the user's scroll direction is set.
            let vertical = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
            let delta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) ? vertical : event.scrollingDeltaX

            if !event.hasPreciseScrollingDeltas {
                // A wheel notch is one step.
                let steps = max(-5, min(5, delta.rounded(.awayFromZero)))
                if steps != 0 { onScroll(Double(steps), true) }
                return true
            }

            if event.phase.contains(.began) { accumulated = 0 }
            accumulated += delta
            let steps = (accumulated / pointsPerStep).rounded(.towardZero)
            if steps != 0 {
                accumulated -= steps * pointsPerStep
                // Smooth-scrolling mice report no gesture phases, so there's no "lifted" event to wait for.
                onScroll(Double(steps), event.phase.isEmpty)
            }
            // Lifting the fingers sends the final value, so the receiver lands where the display is.
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                accumulated = 0
                onScroll(0, true)
            }
            return true
        }
    }
}
#endif
