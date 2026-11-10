import SwiftUI

/// Fake visualizer for the closed right wing (SPEC §5.3). Each bar eases between random target heights.
/// Redraws at most 30 times a second, and only while playing; paused = frozen and dimmed.
struct MusicBarsView: View {
    let count: Int
    let speed: Double
    let color: Color
    let playing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate * max(0.1, speed)
            GeometryReader { geo in
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<count, id: \.self) { i in
                        Capsule()
                            .fill(color)
                            .frame(width: 3, height: max(3, geo.size.height * Self.level(bar: i, time: t)))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .opacity(playing ? 1 : 0.4)
    }

    /// Smoothly interpolated pseudo-random level in 0.2…1.
    private static func level(bar: Int, time: Double) -> Double {
        let period = 0.22 + 0.06 * Double(bar % 3)
        let x = time / period + Double(bar) * 0.37
        let k = floor(x)
        let f = x - k
        let a = rand(bar, Int(k)), b = rand(bar, Int(k) + 1)
        let s = f * f * (3 - 2 * f)
        return 0.2 + 0.8 * (a + (b - a) * s)
    }

    private static func rand(_ bar: Int, _ k: Int) -> Double {
        let v = sin(Double(bar &* 7919 &+ k &* 104_729) * 12.9898) * 43_758.5453
        return v - floor(v)
    }
}
