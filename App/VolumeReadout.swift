import SwiftUI

/// The volume as a row of digits. Each digit keeps its identity by place value (counted from the
/// decimal point), so going from 9.5 to 10.0 rolls the ones and tenths in place while a new tens
/// digit grows in and the row eases back to centre, instead of the whole number jumping.
struct VolumeReadout: View {
    let volume: Double
    /// Always show one decimal (the zone supports half steps).
    let halfSteps: Bool
    let size: CGFloat
    var muted = false

    private struct Glyph: Identifiable {
        let id: String
        let character: Character
    }

    private var text: String {
        volume.formatted(.number.precision(halfSteps ? .fractionLength(1) : .fractionLength(0...1)))
    }

    private var glyphs: [Glyph] {
        let characters = Array(text)
        let point = characters.firstIndex { !$0.isNumber } ?? characters.count
        return characters.enumerated().map { i, c in
            Glyph(id: i < point ? "int\(point - 1 - i)" : (i == point ? "point" : "frac\(i - point - 1)"), character: c)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(glyphs) { glyph in
                Text(String(glyph.character))
                    .contentTransition(.numericText(value: volume))
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .font(.system(size: size, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .fixedSize()
        .animation(.snappy(duration: 0.3), value: text)
        .opacity(muted ? 0.3 : 1)
        .animation(.smooth(duration: 0.3), value: muted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Volume")
        .accessibilityValue(text)
    }
}
