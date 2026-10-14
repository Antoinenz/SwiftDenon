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
        #if os(iOS)
        .sensoryFeedback(.impact, trigger: active)
        #endif
    }
}

/// Capsule volume slider with a glass thumb.
struct GlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var dimmed = false
    var onEnd: () -> Void = {}

    private let thumb: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.width - thumb)
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let x = CGFloat(min(1, max(0, fraction))) * usable
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
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let f = min(1, max(0, (g.location.x - thumb / 2) / usable))
                        let raw = range.lowerBound + Double(f) * (range.upperBound - range.lowerBound)
                        value = (raw * 2).rounded() / 2
                    }
                    .onEnded { _ in onEnd() }
            )
        }
        .frame(height: thumb + 6)
    }
}
