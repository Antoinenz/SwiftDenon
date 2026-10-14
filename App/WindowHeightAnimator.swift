#if os(macOS)
import SwiftUI
import AppKit

/// Animates the window's height (top edge fixed) to match the content's target height.
/// SwiftUI resizes windows instantly; this drives the resize through AppKit instead.
struct WindowHeightAnimator: NSViewRepresentable {
    let height: CGFloat   // height of the content area below the toolbar

    final class Coordinator { var sized = false }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        let first = !context.coordinator.sized
        DispatchQueue.main.async {
            guard let w = view.window else { return }
            context.coordinator.sized = true
            w.styleMask.remove(.resizable)          // height is driven by content, not by dragging
            w.standardWindowButton(.zoomButton)?.isEnabled = false
            let chrome = w.frame.height - w.contentLayoutRect.height
            let target = height + chrome
            let f = w.frame
            guard abs(f.height - target) > 0.5 else { return }
            let new = NSRect(x: f.minX, y: f.maxY - target, width: f.width, height: target)
            w.setFrame(new, display: true, animate: !first)
        }
    }
}
#endif
