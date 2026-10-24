import AppKit
import SwiftUI

@main
struct StorytellerApp: App {
    @State private var store = Store()
    @AppStorage(TextZoom.key) private var zoom = 1.0

    init() {
        // Lets `swift run` show a normal window and Dock icon too.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Storyteller") {
            ContentView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .frame(minWidth: 900, minHeight: 580)
                .onAppear { NSApplication.shared.activate() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.flushSaves()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Story") { store.selection = nil }.keyboardShortcut("n")
            }
            CommandGroup(before: .toolbar) {
                Button("Zoom In") { zoom = TextZoom.clamp(zoom + TextZoom.step) }.keyboardShortcut("=")
                Button("Zoom Out") { zoom = TextZoom.clamp(zoom - TextZoom.step) }.keyboardShortcut("-")
                Button("Actual Size") { zoom = 1 }.keyboardShortcut("0")
                Divider()
            }
        }
    }
}
