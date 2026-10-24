import AppKit
import SwiftUI

/// Hold ⌘ to show a key on each story in the sidebar; ⌘+key jumps to it.
@MainActor @Observable
final class QuickSwitch {
    /// 1–9, then letters that don't clash with app/system shortcuts
    /// (skips a c h j m n q r v w x z and others in use).
    static let keys: [Character] = Array("123456789bdefgiklopstuy")

    var showHints = false
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var revealTask: Task<Void, Never>?

    static func key(for index: Int) -> Character? { index < keys.count ? keys[index] : nil }

    /// `select` gets the story index and returns whether it existed.
    func start(select: @escaping @MainActor (Int) -> Bool) {
        guard monitors.isEmpty else { return }

        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            let commandOnly = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
            MainActor.assumeIsolated { self?.commandHeld(commandOnly) }
            return event
        }) { monitors.append(m) }

        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  let char = event.charactersIgnoringModifiers?.lowercased().first,
                  let index = Self.keys.firstIndex(of: char)
            else {
                // Another shortcut (⌘R, ⌘N…): don't flash the hints.
                MainActor.assumeIsolated { self?.commandHeld(false) }
                return event
            }
            return MainActor.assumeIsolated { select(index) } ? nil : event
        }) { monitors.append(m) }

        // Releasing ⌘ in another app never reaches us.
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.commandHeld(false) }
        }
    }

    private func commandHeld(_ held: Bool) {
        revealTask?.cancel()
        guard held else {
            if showHints { withAnimation(.easeOut(duration: 0.12)) { showHints = false } }
            return
        }
        // Short delay so quick ⌘ shortcuts don't flash badges.
        revealTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.15)) { showHints = true }
        }
    }
}

/// Small key badge shown while ⌘ is held.
struct KeyHint: View {
    let key: Character

    var body: some View {
        Text(String(key).uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.text)
            .frame(minWidth: 20, minHeight: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.14)))
            .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}
