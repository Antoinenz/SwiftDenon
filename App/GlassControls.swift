import SwiftUI

/// Round glass button; tinted when `active`.
struct GlassCircleButton: View {
    let symbol: String
    var active = false
    var tint: Color = .accentColor
    var size: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .medium))
                .frame(width: size, height: size)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(active ? .regular.tint(tint.opacity(0.55)).interactive() : .regular.interactive(), in: .circle)
    }
}

/// Capsule volume slider with a glass thumb. The thumb follows the pointer continuously;
/// only the reported value snaps (to whole numbers, or half steps for slow drags when enabled).
struct GlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var dimmed = false
    /// 0.5 steps enabled. Even then, fast drags snap to whole numbers.
    var halfStep = false
    var onEnd: () -> Void = {}

    private let thumb: CGFloat = 30
    private let fastSpeed: CGFloat = 350
    @State private var dragFraction: Double?
    @State private var lastX: CGFloat = 0
    @State private var lastTime: Date = .distantPast
    @State private var speed: CGFloat = 0   // smoothed points/second
    @State private var lastWhole = -1

    var body: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.width - thumb)
            let valueFraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let fraction = min(1, max(0, dragFraction ?? valueFraction))
            let x = CGFloat(fraction) * usable
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.12)).frame(height: 8)
                Capsule().fill(.primary.opacity(dimmed ? 0.25 : 0.8))
                    .frame(width: x + thumb / 2, height: 8)
                Circle().fill(.clear)
                    .frame(width: thumb, height: thumb)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .animation(dragFraction == nil ? .smooth(duration: 0.25) : nil, value: value)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let dt = g.time.timeIntervalSince(lastTime)
                        if dt > 0.3 { speed = 0 }
                        else if dt > 0 { speed = speed * 0.6 + abs(g.location.x - lastX) / dt * 0.4 }
                        lastX = g.location.x; lastTime = g.time

                        let f = min(1, max(0, (g.location.x - thumb / 2) / usable))
                        dragFraction = f
                        let raw = range.lowerBound + Double(f) * (range.upperBound - range.lowerBound)
                        let snapped = halfStep && speed < fastSpeed ? (raw * 2).rounded() / 2 : raw.rounded()
                        if snapped != value { value = snapped }
                        if Int(snapped) != lastWhole { lastWhole = Int(snapped); Haptics.tick() }
                    }
                    .onEnded { _ in
                        speed = 0; lastTime = .distantPast; lastWhole = -1
                        withAnimation(.smooth(duration: 0.2)) { dragFraction = nil }
                        onEnd()
                    }
            )
        }
        .frame(height: thumb + 6)
    }
}

/// Vertical glass slider used for the EQ bands. Integer steps, centered at zero.
struct VerticalGlassSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    private let thumb: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.height - thumb)
            let f = Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)
            let y = usable * (1 - CGFloat(f))
            ZStack(alignment: .top) {
                Capsule().fill(.primary.opacity(0.12)).frame(width: 8)
                    .frame(maxWidth: .infinity)
                Circle().fill(.clear)
                    .frame(width: thumb, height: thumb)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .frame(maxWidth: .infinity)
                    .offset(y: y)
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    let p = min(1, max(0, 1 - (g.location.y - thumb / 2) / usable))
                    let v = range.lowerBound + Int((p * Double(range.upperBound - range.lowerBound)).rounded())
                    if v != value { value = v }
                }
            )
        }
    }
}
