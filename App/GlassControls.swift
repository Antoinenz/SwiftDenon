import SwiftUI

/// Round native glass button (hover, press and focus handled by the system). One button style
/// throughout so state changes animate: the tint fades in and the icon swaps with a symbol effect.
struct GlassCircleButton: View {
    let symbol: String
    var active = false
    var tint: Color = .accentColor
    var size: CGFloat = 52
    var iconSize: CGFloat?
    let action: () -> Void

    var body: some View {
        #if os(iOS)
        // iOS's glass button style didn't show the tint, so the glass is applied directly.
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize ?? size * 0.38, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .foregroundStyle(active ? Color.white : Color.primary)
                .glassEffect(.regular.tint(active ? tint.opacity(0.7) : nil).interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: active)
        .animation(.snappy, value: symbol)
        #else
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize ?? size * 0.38, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .foregroundStyle(active ? Color.white : Color.primary)
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.glass)
        .tint(active ? tint.opacity(0.7) : nil)
        .animation(.snappy, value: active)
        .animation(.snappy, value: symbol)
        #endif
    }
}

/// Capsule volume slider with a glass thumb. The thumb follows the pointer continuously;
/// only the reported value snaps (to whole numbers, or half steps for slow drags when enabled).
///
/// Two ways to drag. By default (Mac) pressing the track makes the thumb bounce to the pointer.
/// With `relative` (iPhone) the thumb stays where it is when touched and then moves exactly as
/// far as the finger does, so a finger can start anywhere on the slider without anything jumping.
struct GlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var dimmed = false
    /// 0.5 steps enabled. Even then, fast drags snap to whole numbers.
    var halfStep = false
    var relative = false
    /// Called when the pointer lifts, with the last value the drag reported. It is passed in
    /// because a fast tap can end before the view has re-rendered, so reading the current value
    /// from the view could send the old one back to the receiver.
    var onEnd: (Double) -> Void = { _ in }

    private let thumb: CGFloat = 30
    private let fastSpeed: CGFloat = 350
    @State private var dragFraction: Double?
    @State private var lastX: CGFloat = 0
    @State private var lastTime: Date = .distantPast
    @State private var speed: CGFloat = 0   // smoothed points/second
    @State private var lastWhole = -1
    /// The last value this drag set, if it set one.
    @State private var reported: Double?
    /// From the press until the pointer moves away from where it landed: the thumb bounces over to
    /// the cursor. Afterwards it follows the drag on a stiff spring.
    @State private var landing = false
    @State private var pressX: CGFloat = 0
    @State private var startFraction: Double = 0

    private var thumbAnimation: Animation? {
        if dragFraction == nil { return .smooth(duration: 0.2) }
        if relative { return nil }   // the thumb is the finger: no lag
        return landing ? .bouncy(duration: 0.55, extraBounce: 0.25) : .interactiveSpring(response: 0.14, dampingFraction: 0.85)
    }

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
            // The innermost modifier wins when both change in one transaction (a press changes the
            // value and the drag position together), so the drag animation goes first.
            .animation(thumbAnimation, value: dragFraction)
            .animation(dragFraction == nil ? .smooth(duration: 0.25) : nil, value: value)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let dt = g.time.timeIntervalSince(lastTime)
                        if dt > 0.3 { speed = 0 }
                        else if dt > 0 { speed = speed * 0.6 + abs(g.location.x - lastX) / dt * 0.4 }
                        lastX = g.location.x; lastTime = g.time

                        let first = dragFraction == nil
                        let f: Double
                        if relative {
                            if first { startFraction = valueFraction; pressX = g.location.x }
                            f = min(1, max(0, startFraction + Double((g.location.x - pressX) / usable)))
                        } else {
                            if first { landing = true; pressX = g.location.x }
                            else if landing, abs(g.location.x - pressX) > 6 { landing = false }
                            f = min(1, max(0, (g.location.x - thumb / 2) / usable))
                        }
                        dragFraction = f
                        // Touching the thumb is not a change: nothing is reported until it moves.
                        if relative && first { lastWhole = Int(value); return }

                        let raw = range.lowerBound + f * (range.upperBound - range.lowerBound)
                        let snapped = halfStep && speed < fastSpeed ? (raw * 2).rounded() / 2 : raw.rounded()
                        reported = snapped
                        if snapped != value { value = snapped }
                        // The press itself is silent; only crossing values while dragging ticks.
                        if Int(snapped) != lastWhole {
                            if lastWhole >= 0 { Haptics.tick() }
                            lastWhole = Int(snapped)
                        }
                    }
                    .onEnded { _ in
                        speed = 0; lastTime = .distantPast; lastWhole = -1
                        landing = false
                        dragFraction = nil
                        if let reported { onEnd(reported) }
                        reported = nil
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

/// A segmented control that behaves like the toolbar's. At rest the selection is a soft pill on a
/// glass track; pressing it lifts the pill into a glass lens that swells past the track and
/// follows the pointer, changing the selection as it passes over each segment. A popover has no
/// toolbar to supply the real one, so the menu bar's zone picker is built from this.
struct GlassSegmented<Option: Hashable, Label: View>: View {
    @Binding var selection: Option
    let options: [Option]
    var fontSize: CGFloat = 13
    var height: CGFloat = 28
    @ViewBuilder let label: (Option) -> Label

    @State private var pressed = false
    @State private var segmentWidth: CGFloat = 0
    private let inset: CGFloat = 3

    private var index: Int { options.firstIndex(of: selection) ?? 0 }

    var body: some View {
        ZStack(alignment: .leading) {
            thumb
            HStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    // All labels stacked (hidden) so every segment is as wide as the widest one.
                    ZStack {
                        ForEach(options, id: \.self) { label($0).hidden() }
                        label(option)
                    }
                    .font(.system(size: fontSize, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(height: height)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { segmentWidth = $0 / CGFloat(max(1, options.count)) }
        }
        .padding(inset)
        .glassEffect(.regular, in: .capsule)
        .contentShape(.capsule)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { g in
                    pressed = true
                    guard segmentWidth > 0 else { return }
                    let i = min(options.count - 1, max(0, Int((g.location.x - inset) / segmentWidth)))
                    if options[i] != selection {
                        Haptics.tick()
                        selection = options[i]
                    }
                }
                .onEnded { _ in pressed = false }
        )
        .animation(.bouncy(duration: 0.4, extraBounce: 0.1), value: index)
        .animation(.smooth(duration: 0.2), value: pressed)
    }

    @ViewBuilder private var thumb: some View {
        Group {
            if pressed {
                Capsule().fill(.clear).glassEffect(.regular.interactive(), in: .capsule)
            } else {
                Capsule().fill(.primary.opacity(0.2))
            }
        }
        .frame(width: segmentWidth, height: height)
        .scaleEffect(pressed ? 1.18 : 1)
        .offset(x: CGFloat(index) * segmentWidth)
    }
}
