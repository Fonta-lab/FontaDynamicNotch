import SwiftUI
import AppKit
import QuartzCore

/// Fake visualizer for the closed right wing (SPEC §5.3). The bars are Core Animation layers that
/// ease between random heights; macOS's render server animates them, so the app itself does almost
/// no work per frame. Paused = frozen in place and dimmed.
struct MusicBarsView: NSViewRepresentable {
    let count: Int
    let speed: Double
    let color: Color
    let playing: Bool
    /// False with Reduce Motion: the bars stand still (still dimmed when paused).
    var animated = true

    func makeNSView(context: Context) -> BarsLayerView { BarsLayerView() }

    func updateNSView(_ view: BarsLayerView, context: Context) {
        view.configure(count: count, speed: speed, color: NSColor(color), playing: playing, animated: animated)
    }
}

final class BarsLayerView: NSView {
    private var bars: [CALayer] = []
    private var config: (count: Int, speed: Double)?
    /// Whether the bars are moving (playing and motion allowed).
    private var running = true

    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 2
    /// Heights the bars move between, as a fraction of the full height.
    private let steps = 10

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(count: Int, speed: Double, color: NSColor, playing: Bool, animated: Bool) {
        if config?.count != count || config?.speed != speed {
            config = (count, speed)
            rebuildBars()
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bars.forEach { $0.backgroundColor = color.cgColor }
        CATransaction.commit()
        setRunning(playing && animated)
        layer?.opacity = playing ? 1 : 0.4   // paused = dimmed
    }

    override func layout() {
        super.layout()
        layoutBars()
    }

    private func rebuildBars() {
        bars.forEach { $0.removeFromSuperlayer() }
        guard let root = layer, let config else { return }
        bars = (0..<config.count).map { i in
            let bar = CALayer()
            bar.cornerRadius = barWidth / 2
            bar.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            root.addSublayer(bar)
            bar.add(animation(for: i, speed: config.speed), forKey: "level")
            return bar
        }
        layoutBars()
        if !running { freeze() }
    }

    private func layoutBars() {
        guard !bars.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let total = CGFloat(bars.count) * barWidth + CGFloat(bars.count - 1) * spacing
        var x = (bounds.width - total) / 2
        for bar in bars {
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: bounds.height)
            bar.position = CGPoint(x: x + barWidth / 2, y: bounds.midY)
            x += barWidth + spacing
        }
        CATransaction.commit()
    }

    /// A looping height animation with its own random targets and tempo per bar.
    private func animation(for index: Int, speed: Double) -> CAKeyframeAnimation {
        var rng = SystemRandomNumberGenerator()
        var values = (0..<steps).map { _ in Double.random(in: 0.2...1, using: &rng) }
        values.append(values[0])   // loop seamlessly
        let a = CAKeyframeAnimation(keyPath: "transform.scale.y")
        a.values = values
        a.calculationMode = .cubic
        let period = (0.22 + 0.06 * Double(index % 3)) / max(0.1, speed)
        a.duration = period * Double(steps)
        a.repeatCount = .infinity
        a.timeOffset = Double.random(in: 0...a.duration)
        a.isRemovedOnCompletion = false
        return a
    }

    private func setRunning(_ on: Bool) {
        guard on != running else { return }
        running = on
        if on { unfreeze() } else { freeze() }
    }

    private func freeze() {
        guard let root = layer, root.speed != 0 else { return }
        let t = root.convertTime(CACurrentMediaTime(), from: nil)
        root.speed = 0
        root.timeOffset = t
    }

    private func unfreeze() {
        guard let root = layer, root.speed == 0 else { return }
        let paused = root.timeOffset
        root.speed = 1
        root.timeOffset = 0
        root.beginTime = 0
        root.beginTime = root.convertTime(CACurrentMediaTime(), from: nil) - paused
    }
}
