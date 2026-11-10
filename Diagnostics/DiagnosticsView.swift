import SwiftUI

@MainActor
final class DiagModel: ObservableObject {
    @Published var log: [String] = []
    let spotify = SpotifyProbe()
    let mouse = MouseProbe()
    let fsPanel = FullscreenProbePanel()

    init() {
        spotify.onLog = { [weak self] in self?.add($0) }
        fsPanel.onLog = { [weak self] in self?.add($0) }
        mouse.onCount = { [weak self] in self?.add("Mouse events seen so far: \($0)") }
    }
    func add(_ s: String) { log.append("• " + s) }

    func screen() {
        add("(a) Screen brightness: computing…")
        Task.detached { let r = BrightnessProbe.screen(); await MainActor.run { self.add("(a) Screen brightness → \(r)") } }
    }
    func keyboard() {
        Task.detached { let r = BrightnessProbe.keyboard(); await MainActor.run { self.add("(b) Keyboard backlight → \(r)") } }
    }
    func startMouse() {
        mouse.start()
        add("(d) Mouse monitor installed. Move the mouse over OTHER apps/desktop; the counter should grow. (If it stays at 0, a permission is needed.)")
    }
    func fsToggle() {
        let on = fsPanel.toggle()
        add("(e) Red test bar is \(on ? "ON — now put another app (e.g. Safari) into full screen and watch the log: the app now checks for full-screen windows and hides the bar if it finds one" : "OFF")")
    }
}

struct DiagnosticsView: View {
    @StateObject private var m = DiagModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("M0 – Risk checks").font(.title2.bold())
            Group {
                row("(a) Screen brightness", "Test") { m.screen() }
                row("(b) Keyboard backlight", "Test") { m.keyboard() }
                HStack {
                    Text("(c) Spotify").frame(width: 170, alignment: .leading)
                    Button("Listen for events") { m.spotify.startListening(); m.add("(c) Listening for Spotify playback events. Play/pause/skip a song in Spotify.") }
                    Button("Read state") { m.spotify.read() }
                    Button("Play/Pause") { m.spotify.playPause() }
                    Button("Repeat test") { m.spotify.toggleRepeat() }
                }
                row("(d) Mouse tracking", "Start") { m.startMouse() }
                row("(e) Full screen", "Show/hide red bar") { m.fsToggle() }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(m.log.enumerated()), id: \.offset) { _, l in
                        Text(l).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Button("Copy log") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(m.log.joined(separator: "\n"), forType: .string)
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 480)
    }

    func row(_ title: String, _ button: String, _ action: @escaping () -> Void) -> some View {
        HStack { Text(title).frame(width: 170, alignment: .leading); Button(button, action: action) }
    }
}
