#if os(macOS)
import AppKit
import Observation

/// The app icon's dial, redrawn as a menu bar template image: a knob with an indicator, ringed
/// by 11 ticks. The indicator sweeps with the volume and the ticks up to it light up.
enum MenuBarDial {
    enum Mode { case playing, muted, off }

    /// Same geometry as `App/AppIcon.icon`: 270° sweep from bottom-left, clockwise.
    static let tickCount = 11
    static let sweep = 270.0

    static func image(fraction: Double, mode: Mode) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let f = min(1, max(0, fraction))
            let angle = -sweep / 2 + sweep * f            // degrees clockwise from straight up

            func point(_ r: CGFloat, _ degrees: Double) -> CGPoint {
                let a = degrees * .pi / 180
                return CGPoint(x: c.x + r * CGFloat(sin(a)), y: c.y + r * CGFloat(cos(a)))
            }

            // Ticks: lit up to the indicator, dim after (all dim when off or muted).
            for i in 0..<tickCount {
                let a = -sweep / 2 + sweep / Double(tickCount - 1) * Double(i)
                let lit = mode == .playing && a <= angle + 0.5
                let p = point(7.8, a)
                ctx.setFillColor(NSColor.black.withAlphaComponent(lit ? 1 : 0.35).cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - 0.85, y: p.y - 0.85, width: 1.7, height: 1.7))
            }

            // Knob: solid while on, a ring in standby.
            let knob = CGRect(x: c.x - 4.8, y: c.y - 4.8, width: 9.6, height: 9.6)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setStrokeColor(NSColor.black.cgColor)
            if mode == .off {
                ctx.setLineWidth(1.2)
                ctx.strokeEllipse(in: knob.insetBy(dx: 0.6, dy: 0.6))
            } else {
                ctx.fillEllipse(in: knob)
                // Indicator is knocked out of the knob.
                ctx.setBlendMode(.clear)
                ctx.setLineWidth(1.5)
                ctx.setLineCap(.round)
                ctx.move(to: point(2.0, angle))
                ctx.addLine(to: point(3.9, angle))
                ctx.strokePath()
                ctx.setBlendMode(.normal)
            }

            // Muted: a slash with a clear gap on either side, like the speaker symbols.
            if mode == .muted {
                let a = CGPoint(x: 2.5, y: 15.5), b = CGPoint(x: 15.5, y: 2.5)
                ctx.setLineCap(.round)
                ctx.setBlendMode(.clear)
                ctx.setLineWidth(4)
                ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
                ctx.setBlendMode(.normal)
                ctx.setLineWidth(1.5)
                ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Feeds the menu bar icon. The receiver reports volume in jumps, so the dial eases toward each
/// new value instead of snapping; SwiftUI doesn't animate a menu bar label itself.
@MainActor @Observable
final class MenuBarIconModel {
    private(set) var image = MenuBarDial.image(fraction: 0, mode: .off)

    private let store: ReceiverStore
    private var displayed = 0.0
    private var mode = MenuBarDial.Mode.off
    private var animation: Task<Void, Never>?
    private var watcher: Task<Void, Never>?

    init(store: ReceiverStore) {
        self.store = store
        watcher = Task { [weak self] in
            let changes = Observations { () -> Target in
                let z = store.zone
                let mode: MenuBarDial.Mode = !store.state.connected || !z.power ? .off : (z.mute ? .muted : .playing)
                return Target(fraction: z.maxVolume > 0 ? z.volume / z.maxVolume : 0, mode: mode)
            }
            for await target in changes { self?.move(to: target) }
        }
    }

    private struct Target: Equatable { var fraction: Double; var mode: MenuBarDial.Mode }

    private func move(to target: Target) {
        mode = target.mode
        animation?.cancel()
        let start = displayed, end = target.fraction
        // The first reading, and anything while off, jumps straight there.
        guard abs(end - start) > 0.001, target.mode != .off else { return set(end) }
        animation = Task { [weak self] in
            let began = ContinuousClock.now
            let duration = 0.35
            while !Task.isCancelled {
                let t = min(1, (ContinuousClock.now - began) / .seconds(duration))
                let eased = 1 - pow(1 - t, 3)               // ease out
                self?.set(start + (end - start) * eased)
                if t >= 1 { return }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func set(_ fraction: Double) {
        displayed = fraction
        image = MenuBarDial.image(fraction: fraction, mode: mode)
    }
}
#endif
