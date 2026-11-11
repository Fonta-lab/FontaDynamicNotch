import SwiftUI

/// Counters (SPEC §10.7): add, rename, delete, reorder. At least one always exists.
struct CounterSettingsView: View {
    private var counters: CounterStore { .shared }

    var body: some View {
        Form {
            Section {
                ForEach(counters.counters) { c in
                    CounterRow(item: c, isOnly: counters.counters.count == 1,
                               isFirst: c.id == counters.counters.first?.id,
                               isLast: c.id == counters.counters.last?.id)
                }
                .onMove { counters.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Counters")
            } footer: {
                HStack {
                    Button("Add counter") { counters.addCounter() }
                    Spacer()
                }
            }
        }
    }
}

struct CounterRow: View {
    let item: CounterItem
    let isOnly: Bool
    let isFirst: Bool
    let isLast: Bool
    @State private var name = ""

    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: name) {
                    let t = name.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty, t != item.name { CounterStore.shared.rename(item.id, to: t) }
                }
            Text("\(item.value)").monospacedDigit().foregroundStyle(.secondary).frame(width: 50, alignment: .trailing)
            Button { CounterStore.shared.move(item.id, by: -1) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless).disabled(isFirst)
            Button { CounterStore.shared.move(item.id, by: 1) } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless).disabled(isLast)
            Button(role: .destructive) { CounterStore.shared.delete(item.id) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).disabled(isOnly)
                .help(isOnly ? "At least one counter always exists" : "Delete")
        }
        .onAppear { name = item.name }
    }
}
