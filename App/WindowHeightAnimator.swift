#if os(macOS)
import SwiftUI
import AppKit

/// Animates the window's height (top edge fixed) to match the content's target height.
/// SwiftUI resizes windows instantly and NSWindow's own animation is unreliable for shrinking,
/// so the frame is stepped manually with the same easing in both directions.
struct WindowHeightAnimator: NSViewRepresentable {
    let height: CGFloat   // height of the content area below the toolbar

    @MainActor
    final class Coordinator {
        var sized = false
        var timer: Timer?

        func resize(_ w: NSWindow, toContent height: CGFloat, animated: Bool) {
            timer?.invalidate()
            let chrome = w.frame.height - w.contentLayoutRect.height
            let target = height + chrome
            let startHeight = w.frame.height
            guard abs(startHeight - target) > 0.5 else { return }
            let top = w.frame.maxY

            func set(_ h: CGFloat) {
                w.setFrame(NSRect(x: w.frame.minX, y: top - h, width: w.frame.width, height: h), display: true)
            }
            guard animated else { set(target); return }

            let start = CACurrentMediaTime(), duration = 0.35
            let t = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    let p = min(1, (CACurrentMediaTime() - start) / duration)
                    let eased = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
                    set(startHeight + (target - startHeight) * CGFloat(eased))
                    if p >= 1 { self?.timer?.invalidate(); self?.timer = nil }
                }
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        let coordinator = context.coordinator
        let first = !coordinator.sized
        DispatchQueue.main.async {
            guard let w = view.window else { return }
            coordinator.sized = true
            w.styleMask.remove(.resizable)          // height is driven by content, not by dragging
            w.standardWindowButton(.zoomButton)?.isEnabled = false
            coordinator.resize(w, toContent: height, animated: !first)
        }
    }
}
#endif
