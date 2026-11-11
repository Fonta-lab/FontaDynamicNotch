import SwiftUI

/// Layout & Modules (SPEC §10.3): reorder and hide the top-bar buttons; sizes.
struct LayoutSettingsView: View {
    @Bindable private var store = SettingsStore.shared

    var body: some View {
        Form {
            Section {
                moduleRows(\.leftModules)
            } header: {
                Text("Left of the notch")
            } footer: {
                Text("Drag to reorder, or use the arrows. Brightness buttons also hide on their own when they can't work (external screen, lid closed).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Right of the notch") {
                moduleRows(\.rightModules)
            }
            Section("Size") {
                LabeledSlider(title: "Open width", value: $store.settings.openWidth, range: 480...820, step: 2,
                              format: { "\(Int($0)) pt" })
                LabeledSlider(title: "Open height", value: $store.settings.openHeight, range: 150...280, step: 2,
                              format: { "\(Int($0)) pt" })
                LabeledSlider(title: "Closed wing width", value: $store.settings.closedWingWidth, range: 28...64, step: 1,
                              format: { "\(Int($0)) pt" })
            }
        }
    }

    private func moduleRows(_ group: WritableKeyPath<AppSettings, [TopModule]>) -> some View {
        let list = store.settings[keyPath: group]
        return ForEach(list) { module in
            let i = list.firstIndex(of: module) ?? 0
            HStack {
                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                Image(systemName: module.symbol).frame(width: 20)
                Toggle(module.title, isOn: Binding(
                    get: { store.settings.isVisible(module) },
                    set: { on in
                        store.settings.hiddenModules.removeAll { $0 == module }
                        if !on { store.settings.hiddenModules.append(module) }
                    }))
                Spacer()
                Button { move(group, i, -1) } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(.borderless).disabled(i == 0)
                Button { move(group, i, 1) } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.borderless).disabled(i == list.count - 1)
            }
        }
        .onMove { from, to in store.settings[keyPath: group].move(fromOffsets: from, toOffset: to) }
    }

    private func move(_ group: WritableKeyPath<AppSettings, [TopModule]>, _ i: Int, _ d: Int) {
        let j = i + d
        guard store.settings[keyPath: group].indices.contains(j) else { return }
        store.settings[keyPath: group].swapAt(i, j)
    }
}
