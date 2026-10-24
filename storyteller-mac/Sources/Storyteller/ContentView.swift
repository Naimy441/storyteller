import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store
    @AppStorage("sidebarWidth") private var sidebarWidth = 252.0

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: sidebarWidth)
            ResizeHandle(width: $sidebarWidth, range: 200...420)
            Group {
                if let id = store.selection, store.adventure(id) != nil {
                    StoryView(id: id).id(id)
                } else {
                    WelcomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg)
        .foregroundStyle(Theme.text)
        .ignoresSafeArea()
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Environment(Store.self) private var store
    @State private var quick = QuickSwitch()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room for the traffic lights.
            Color.clear.frame(height: 46).contentShape(Rectangle()).windowDraggable()

            HStack(spacing: 8) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .top, endPoint: .bottom))
                Text("Storyteller").font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)

            NewStoryButton(active: store.selection == nil) { store.selection = nil }

            SectionLabel(title: "Stories")
                .padding(.horizontal, 8)
                .padding(.top, 22)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(store.adventures.enumerated()), id: \.element.id) { i, a in
                        StoryRow(adventure: a, hint: quick.showHints ? QuickSwitch.key(for: i) : nil)
                    }
                }
            }
            .scrollIndicators(.never)

            StatusFooter()
        }
        .padding(.horizontal, 10)
        .background(Theme.sidebar)
        .onAppear {
            quick.start { [store] index in
                guard index < store.adventures.count else { return false }
                store.selection = store.adventures[index].id
                return true
            }
        }
    }
}

private struct NewStoryButton: View {
    let active: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                Text("New story").font(.system(size: 13, weight: .medium))
                Spacer()
                Text("⌘N").font(.system(size: 11)).foregroundStyle(Theme.tertiary)
            }
            .foregroundStyle(active ? Theme.accent : Theme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(active ? Theme.accent.opacity(0.12) : Color.white.opacity(hover ? 0.07 : 0.045)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Theme.accent.opacity(0.25) : Theme.hairline))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

private struct StoryRow: View {
    let adventure: Adventure
    /// Quick-switch key shown while ⌘ is held.
    let hint: Character?
    @Environment(Store.self) private var store
    @State private var hover = false

    var body: some View {
        let selected = store.selection == adventure.id
        let busy = store.generating.contains(adventure.id)
        Button { store.selection = adventure.id } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(adventure.title.isEmpty ? "Untitled" : adventure.title)
                        .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Theme.text : Theme.text.opacity(0.78))
                        .lineLimit(1)
                    if busy {
                        HStack(spacing: 5) {
                            Circle().fill(Theme.accent).frame(width: 5, height: 5)
                                .phaseAnimator([0.3, 1]) { $0.opacity($1) } animation: { _ in .easeInOut(duration: 0.6) }
                            Text("Writing…").font(.system(size: 11)).foregroundStyle(Theme.accent)
                        }
                    } else {
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let hint { KeyHint(key: hint) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(selected ? 0.075 : hover ? 0.035 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .contextMenu {
            Button("Duplicate") { store.duplicate(adventure.id) }
            Divider()
            Button("Delete", role: .destructive) { store.delete(adventure.id) }
        }
    }

    private var subtitle: String {
        let turns = adventure.actions.filter { $0.type != .ai }.count
        let ago = RelativeDateTimeFormatter().localizedString(for: adventure.updatedAt, relativeTo: .now)
        return "\(turns) \(turns == 1 ? "turn" : "turns") · \(ago)"
    }
}

private struct StatusFooter: View {
    @Environment(Store.self) private var store

    var body: some View {
        let models = store.ollamaModels
        HStack(spacing: 8) {
            Circle()
                .fill(models == nil ? Theme.tertiary : models!.isEmpty ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                .frame(width: 7, height: 7)
            Text(models == nil ? "Checking Ollama…" : models!.isEmpty ? "Ollama offline" : "Ollama connected")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.secondary)
            Spacer()
            IconButton(icon: "arrow.clockwise", help: "Recheck Ollama", size: 24) { store.refreshModels() }
            Menu {
                Button("Show in Finder") { NSWorkspace.shared.open(store.dir) }
                Button("Change Folder…") { chooseFolder() }
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Stories folder: \(store.dir.path(percentEncoded: false))")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Theme.hairline.frame(height: 1) }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = store.dir
        panel.prompt = "Use Folder"
        panel.message = "Choose where Storyteller keeps your stories."
        if panel.runModal() == .OK, let url = panel.url { store.changeDirectory(to: url) }
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 46).contentShape(Rectangle()).windowDraggable()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("What story shall we tell?")
                        .font(.system(size: 38, weight: .regular, design: .serif))
                    Text("Choose a world to begin. Everything runs locally on your own model.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 8)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(Presets.all, id: \.name) { p in
                            PresetCard(preset: p) { store.create(p) }
                        }
                    }
                    .padding(.top, 32)
                    Label("Stories save as JSON to \(store.dir.path(percentEncoded: false))", systemImage: "externaldrive")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.tertiary)
                        .padding(.top, 28)
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 40)
                .padding(.vertical, 60)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct PresetCard: View {
    let preset: Preset
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: preset.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Theme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 5) {
                    Text(preset.name).font(.system(size: 15, weight: .semibold))
                    Text(preset.blurb)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16).fill(hover ? Theme.surface2 : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(hover ? Theme.accent.opacity(0.35) : Theme.hairline))
            .shadow(color: .black.opacity(hover ? 0.35 : 0), radius: 18, y: 8)
            .offset(y: hover ? -2 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.18)) { hover = h } }
    }
}
