import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case layout = "Layout & Modules"
    case animations = "Animations"
    case music = "Music"
    case timers = "Timers"
    case counters = "Counters"
    case advanced = "Advanced"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .layout: "rectangle.3.group"
        case .animations: "wand.and.stars"
        case .music: "music.note"
        case .timers: "timer"
        case .counters: "plusminus"
        case .advanced: "wrench.and.screwdriver"
        }
    }
}

struct SettingsView: View {
    @State private var section: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $section) { s in
                Label(s.rawValue, systemImage: s.symbol).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch section ?? .general {
                case .general: GeneralSettingsView()
                case .appearance: AppearanceSettingsView()
                case .layout: LayoutSettingsView()
                case .animations: AnimationSettingsView()
                case .music: MusicSettingsView()
                case .timers: TimerSettingsView()
                case .counters: CounterSettingsView()
                case .advanced: AdvancedSettingsView()
                }
            }
            .formStyle(.grouped)
            .navigationTitle(section?.rawValue ?? "")
        }
    }
}

/// A slider row with a value label.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    var format: (Double) -> String = { String(format: "%.2f", $0) }

    var body: some View {
        LabeledContent(title) {
            HStack {
                if let step {
                    Slider(value: $value, in: range, step: step)
                } else {
                    Slider(value: $value, in: range)
                }
                Text(format(value)).monospacedDigit().frame(width: 64, alignment: .trailing).foregroundStyle(.secondary)
            }
        }
    }
}

extension Binding where Value == CGFloat {
    /// Lets CGFloat theme values use Double sliders.
    var double: Binding<Double> {
        Binding<Double>(get: { Double(wrappedValue) }, set: { wrappedValue = CGFloat($0) })
    }
}
