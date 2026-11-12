import SwiftUI
import UniformTypeIdentifiers

/// Files tab (SPEC §8): the shelf on the left, AirDrop and Trash drop zones on the right.
struct FilesTabView: View {
    let theme: Theme
    private var shelf: ShelfStore { .shared }

    var body: some View {
        HStack(spacing: 10) {
            ShelfView(theme: theme)
            AirDropZone(theme: theme)
                .frame(width: 92)
            TrashZone(theme: theme)
                .frame(width: 92)
        }
    }
}

/// The row of files. Drop files here to keep them; drag them out to use them; click to select.
struct ShelfView: View {
    let theme: Theme
    private var shelf: ShelfStore { .shared }
    @State private var targeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(targeted ? 0.14 : 0.07))
            if shelf.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down").font(.title)
                    Text("Drop files here").font(.callout.weight(.medium))
                }
                .foregroundStyle(theme.secondaryText)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Button("Clear all") { shelf.clear() }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .padding(.trailing, 10)
                        .padding(.top, 6)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(shelf.items) { item in
                                ShelfItemView(item: item, selected: shelf.selection.contains(item.id), theme: theme)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(maxHeight: .infinity)   // files centred in the space under "Clear all"
                    Spacer(minLength: 14)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(targeted ? 0.5 : 0), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
        .dropDestination(for: URL.self) { urls, _ in
            shelf.add(urls)
            return true
        } isTargeted: { targeted = $0 }
        .animation(.easeOut(duration: 0.15), value: targeted)
    }
}

struct ShelfItemView: View {
    let item: ShelfItem
    let selected: Bool
    let theme: Theme
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 3) {
            Group {
                if let t = item.thumbnail {
                    Image(nsImage: t).resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(for: .data)).resizable().aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: 44, height: 44)
            Text(item.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 60, height: 22, alignment: .top)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(selected ? 0.22 : hovering ? 0.08 : 0)))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { ShelfStore.shared.remove(item.id) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Remove from shelf")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { ShelfStore.shared.toggleSelection(item.id) }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .onHover { hovering = $0 }
        .help(item.name)
    }
}

/// Drop files here, or click with shelf items selected, to AirDrop them.
struct AirDropZone: View {
    let theme: Theme
    @State private var targeted = false
    @State private var message: String?

    var body: some View {
        DropZoneBox(symbol: "dot.radiowaves.up.forward", title: "AirDrop", message: message,
                    targeted: targeted, shake: 0, theme: theme)
            .onTapGesture {
                let shelf = ShelfStore.shared
                if shelf.selectedURLs.isEmpty {
                    flash(shelf.items.isEmpty ? "Add files first" : "Select files first")
                } else if !shelf.airDrop(shelf.selectedURLs) {
                    flash("AirDrop unavailable")
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                if !ShelfStore.shared.airDrop(urls) { flash("AirDrop unavailable") }
                return true
            } isTargeted: { targeted = $0 }
    }

    private func flash(_ text: String) {
        message = text
        Task { try? await Task.sleep(for: .seconds(2)); message = nil }
    }
}

/// Drop files here (from the shelf or straight from Finder) to move them to the Trash immediately.
struct TrashZone: View {
    let theme: Theme
    @State private var targeted = false
    @State private var message: String?
    @State private var shakes = 0

    var body: some View {
        DropZoneBox(symbol: targeted ? "trash.fill" : "trash", title: "Trash", message: message,
                    targeted: targeted, shake: shakes, theme: theme)
            .dropDestination(for: URL.self) { urls, _ in
                Task {
                    let failed = await ShelfStore.shared.trash(urls.filter(\.isFileURL))
                    if !failed.isEmpty {
                        withAnimation(.linear(duration: 0.4)) { shakes += 1 }
                        message = failed.count == 1 ? "Couldn't trash \(failed[0])" : "Couldn't trash \(failed.count) files"
                        try? await Task.sleep(for: .seconds(2.5))
                        message = nil
                    }
                }
                return true
            } isTargeted: { targeted = $0 }
    }
}

/// Shared look of the AirDrop and Trash zones.
struct DropZoneBox: View {
    let symbol: String
    let title: String
    let message: String?
    let targeted: Bool
    let shake: Int
    let theme: Theme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title.weight(.medium))
            Text(message ?? title)
                .font((message == nil ? Font.callout : .caption).weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .foregroundStyle(theme.primaryText.opacity(targeted ? 1 : 0.75))
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(targeted ? 0.18 : 0.07)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.white.opacity(targeted ? 0.5 : 0), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        .scaleEffect(targeted ? 1.04 : 1)
        .modifier(ShakeEffect(shakes: CGFloat(shake)))
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: targeted)
    }
}

/// Horizontal shake, used when the Trash zone can't trash a file.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(shakes * .pi * 6), y: 0))
    }
}
