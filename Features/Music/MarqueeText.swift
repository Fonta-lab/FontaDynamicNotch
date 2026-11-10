import SwiftUI

/// One line of text. If it doesn't fit and the mouse is over it, it scrolls; otherwise it's truncated.
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    var enabled = true

    @State private var textWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0
    @State private var hoverStart: Date?

    private let gap: CGFloat = 40
    private let speed: Double = 30   // points per second

    var body: some View {
        let scrolling = enabled && hoverStart != nil && textWidth > boxWidth + 1
        ZStack(alignment: .leading) {
            if scrolling, let start = hoverStart {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                    let cycle = Double(textWidth + gap)
                    let elapsed = max(0, ctx.date.timeIntervalSince(start) - 0.6)   // short pause before scrolling
                    let x = (elapsed * speed).truncatingRemainder(dividingBy: cycle)
                    HStack(spacing: gap) { label; label }
                        .fixedSize()
                        .offset(x: -x)
                }
            } else {
                label.lineLimit(1).truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .background(
            label.fixedSize().hidden()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boxWidth = $0 }
        .contentShape(Rectangle())
        .onHover { hoverStart = $0 ? Date() : nil }
        .onChange(of: text) { hoverStart = hoverStart == nil ? nil : Date() }
    }

    private var label: some View {
        Text(text).font(font).foregroundStyle(color)
    }
}
