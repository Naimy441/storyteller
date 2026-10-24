import SwiftUI

struct StoryView: View {
    let id: UUID
    @Environment(Store.self) private var store
    @AppStorage("showSetup") private var showSetup = true
    @AppStorage("setupWidth") private var setupWidth = 350.0

    var body: some View {
        HStack(spacing: 0) {
            StoryColumn(id: id, showSetup: $showSetup)
                .frame(maxWidth: .infinity)
            if showSetup {
                ResizeHandle(width: $setupWidth, range: 290...600, panelOnRight: true)
                SetupPanel(id: id) { withAnimation(.snappy(duration: 0.25)) { showSetup = false } }
                    .frame(width: setupWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

private struct StoryColumn: View {
    let id: UUID
    @Binding var showSetup: Bool
    @Environment(Store.self) private var store
    @State private var following = true
    /// 0 at the very top, 1 once scrolled a little; drives the top fade.
    @State private var topFade = 0.0
    @State private var position = ScrollPosition(edge: .bottom)
    @AppStorage(TextZoom.key) private var zoom = 1.0
    @State private var pinchStart: Double?

    var body: some View {
        let adv = store.adventure(id) ?? Adventure(title: "")
        let busy = store.generating.contains(id)

        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if adv.actions.isEmpty {
                        EmptyStory()
                    }
                    ForEach(adv.actions) { a in
                        ActionRow(advID: id, action: a, streaming: busy && a.id == adv.actions.last?.id && a.type == .ai)
                    }
                    if let err = store.errors[id] {
                        ErrorBanner(text: err)
                    }
                    // Space for the floating composer.
                    Color.clear.frame(height: 150)
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 52)
                .padding(.top, 76)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.automatic)
            .scrollPosition($position)
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        let start = pinchStart ?? zoom
                        pinchStart = start
                        zoom = TextZoom.clamp(start * v.magnification)
                    }
                    .onEnded { _ in pinchStart = nil }
            )
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            // While following, growing text stays glued to the bottom natively
            // (no per-token scroll calls, so it moves smoothly).
            .defaultScrollAnchor(following ? .bottom : nil, for: .sizeChanges)
            .onScrollGeometryChange(for: ScrollMetrics.self) { g in
                ScrollMetrics(offset: g.contentOffset.y,
                              distanceFromBottom: g.contentSize.height - g.contentOffset.y - g.containerSize.height)
            } action: { old, new in
                topFade = min(max(new.offset / 40, 0), 1)
                // Only a real upward scroll stops following; text growing below us doesn't.
                if new.distanceFromBottom < 60 { following = true }
                else if new.offset < old.offset - 1 { following = false }
            }
            .onChange(of: adv.actions.count) {
                following = true
                withAnimation(.easeOut(duration: 0.25)) { position.scrollTo(edge: .bottom) }
            }
            .task {
                // Wait one layout pass so the full story height is known.
                try? await Task.sleep(for: .milliseconds(50))
                position.scrollTo(edge: .bottom)
            }

            // Fades so text scrolls softly under the top bar and composer.
            VStack {
                LinearGradient(stops: [.init(color: Theme.bg, location: 0), .init(color: Theme.bg, location: 0.45),
                                       .init(color: Theme.bg.opacity(0), location: 1)],
                               startPoint: .top, endPoint: .bottom).frame(height: 100)
                    .opacity(topFade)
                Spacer()
                LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom).frame(height: 160)
            }
            .allowsHitTesting(false)

            Composer(id: id, busy: busy, hasActions: !adv.actions.isEmpty)
                .padding(.horizontal, 28)
                .padding(.bottom, 22)
        }
        .overlay(alignment: .top) {
            TopBar(id: id, title: adv.title, busy: busy, showSetup: $showSetup)
        }
    }
}

private struct TopBar: View {
    let id: UUID
    let title: String
    let busy: Bool
    @Binding var showSetup: Bool
    @AppStorage(TextZoom.key) private var zoom = 1.0

    var body: some View {
        HStack(spacing: 10) {
            Text(title.isEmpty ? "Untitled" : title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            if busy {
                Text("Writing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
                    .transition(.opacity)
            }
            Spacer()
            if zoom != 1 {
                Button { zoom = 1 } label: {
                    Text("\(Int((zoom * 100).rounded()))%")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .help("Text zoom — click to reset (⌘0)")
            }
            if !showSetup {
                IconButton(icon: "sidebar.right", help: "Story setup") {
                    withAnimation(.snappy(duration: 0.25)) { showSetup = true }
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 46)
        .contentShape(Rectangle())
        .windowDraggable()
        .animation(.easeOut(duration: 0.2), value: busy)
    }
}

private struct EmptyStory: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "pencil.and.scribble").font(.system(size: 22)).foregroundStyle(Theme.accent)
            Text("A blank page.").font(.system(size: 22, design: .serif))
            Text("Switch to Story mode below and write your opening — or set the scene in Story Setup first.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
        }
        .padding(.top, 40)
    }
}

private struct ErrorBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color(red: 1, green: 0.55, blue: 0.5))
            Text(text).font(.system(size: 13)).foregroundStyle(Color(red: 1, green: 0.78, blue: 0.75))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2)))
    }
}

// MARK: - Composer

private struct Composer: View {
    let id: UUID
    let busy: Bool
    let hasActions: Bool
    @Environment(Store.self) private var store
    @State private var mode: ActionType = .do
    @State private var input = ""
    @FocusState private var focused: Bool
    @Namespace private var pill
    @AppStorage(TextZoom.key) private var zoom = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(mode.hint, text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15 * zoom))
                .lineLimit(1...8)
                .focused($focused)
                .focusEffectDisabled()
                .onSubmit(send)
                .padding(.horizontal, 4)
                .padding(.top, 2)

            HStack(spacing: 4) {
                modePicker
                Spacer()
                if let adv = store.adventure(id) {
                    ContextRing(adventure: adv)
                }
                IconButton(icon: "arrow.uturn.backward", help: "Undo (⌘⌥Z)") { store.undo(id) }
                    .disabled(!hasActions)
                    .keyboardShortcut("z", modifiers: [.command, .option])
                IconButton(icon: "arrow.uturn.forward", help: "Redo") { store.redo(id) }
                    .disabled(busy || !store.canRedo(id))
                IconButton(icon: "arrow.clockwise", help: "Retry (⌘R)") { store.retry(id) }
                    .disabled(busy || !hasActions)
                    .keyboardShortcut("r", modifiers: .command)
                sendButton.padding(.leading, 6)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(focused ? Theme.accent.opacity(0.35) : Color.white.opacity(0.09)))
        .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
        .frame(maxWidth: 720)
        .animation(.easeOut(duration: 0.15), value: focused)
        .onAppear {
            // Restore any unsent text from last time.
            if let adv = store.adventure(id) {
                input = adv.draft
                mode = adv.draftMode
            }
            focused = true
        }
        .onChange(of: input) { store.setDraft(id, text: input, mode: mode) }
        .onChange(of: mode) { store.setDraft(id, text: input, mode: mode) }
    }

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach([(ActionType.do, "figure.walk"), (.say, "quote.bubble"), (.story, "text.book.closed"), (.guide, "signpost.right")], id: \.0) { type, icon in
                let selected = mode == type
                Button {
                    withAnimation(.snappy(duration: 0.22)) { mode = type }
                    focused = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                        Text(type.label).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(selected ? Theme.accent : Theme.secondary)
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background {
                        if selected {
                            Capsule().fill(Theme.accent.opacity(0.14)).matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.bg))
        .overlay(Capsule().stroke(Theme.hairline))
    }

    private var sendButton: some View {
        let kind: PrimaryButton.Kind = busy ? .stop : input.trimmed.isEmpty ? .continue : .send
        return PrimaryButton(kind: kind) {
            if busy { store.stop(id) } else { send() }
        }
        .keyboardShortcut(busy ? .cancelAction : .init(.return, modifiers: .command))
    }

    private func send() {
        guard !busy else { return }
        store.submit(id, type: mode, text: input)
        input = ""
    }
}

// MARK: - Story passages

private struct ActionRow: View {
    let advID: UUID
    let action: StoryAction
    let streaming: Bool
    @Environment(Store.self) private var store
    @State private var editing = false
    @State private var draft = ""
    @State private var hover = false
    @AppStorage(TextZoom.key) private var zoom = 1.0

    private var isPlayer: Bool { action.type == .do || action.type == .say }

    var body: some View {
        Group {
            if editing {
                editor
            } else if isPlayer {
                HStack(alignment: .top, spacing: 12) {
                    Capsule().fill(Theme.accent).frame(width: 2.5)
                    Text(String(Prompt.format(action).dropFirst(2)))
                        .font(.system(size: 15 * zoom, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .lineSpacing(4 * zoom)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 2)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let guide = action.guide {
                        Label(guide, systemImage: "signpost.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.tertiary)
                            .help("This passage was written with this Guide direction")
                    }
                    passage
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            // Sits in the right margin, outside the text column, so it never covers words.
            if hover && !streaming && !editing {
                VStack(spacing: 0) {
                    IconButton(icon: "pencil", help: "Edit", size: 26) { startEditing() }
                    IconButton(icon: "trash", help: "Delete", size: 26) { store.deleteAction(advID, actionID: action.id) }
                }
                .padding(2)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.hairline))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
                // Toolbar is 30pt wide; push it fully past the text plus a 10pt gap.
                .offset(x: 40)
                .transition(.opacity)
            }
        }
        // Extend the hover area into the margin so the toolbar stays reachable.
        .padding(.trailing, 46)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
        .padding(.trailing, -46)
        .contextMenu {
            Button("Edit") { startEditing() }
            Button("Delete", role: .destructive) { store.deleteAction(advID, actionID: action.id) }
        }
    }

    @ViewBuilder private var passage: some View {
        if streaming && action.text.isEmpty {
            TypingDots().padding(.vertical, 6)
        } else {
            (Text(Prompt.format(action)) + Text(streaming ? " ▍" : "").foregroundColor(Theme.accent))
                .font(Theme.story(zoom))
                .lineSpacing(9 * zoom)
                .foregroundStyle(Theme.text.opacity(0.92))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $draft)
                .font(isPlayer ? .system(size: 15 * zoom) : Theme.story(zoom))
                .lineSpacing((isPlayer ? 4 : 9) * zoom)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 100)
                .fixedSize(horizontal: false, vertical: true)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.4)))
            HStack(spacing: 8) {
                Button("Cancel") { editing = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .keyboardShortcut(.cancelAction)
                Button {
                    if draft.trimmed.isEmpty { store.deleteAction(advID, actionID: action.id) }
                    else { store.editAction(advID, actionID: action.id, text: draft) }
                    editing = false
                } label: {
                    Text("Save").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.85))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    private func startEditing() {
        draft = action.text
        editing = true
    }
}

/// The composer's main button: morphs between Continue, Send and Stop.
private struct PrimaryButton: View {
    enum Kind { case `continue`, send, stop }
    let kind: Kind
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(kind == .stop ? Theme.text : Color.black.opacity(0.82))
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .frame(height: 34)
            .background {
                if kind == .stop {
                    Capsule().fill(Color.white.opacity(hover ? 0.14 : 0.09))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12)))
                } else {
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.accent.opacity(hover ? 1 : 0.95), Theme.accentDeep],
                                             startPoint: .top, endPoint: .bottom))
                        // Soft top highlight for a bit of depth.
                        .overlay(Capsule().stroke(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                                 startPoint: .top, endPoint: .center), lineWidth: 1))
                        .shadow(color: Theme.accent.opacity(hover ? 0.45 : 0.25), radius: hover ? 14 : 9, y: 3)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressScale())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
        .help(help)
    }

    private var label: String {
        switch kind {
        case .continue: "Continue"
        case .send: "Send"
        case .stop: "Stop"
        }
    }

    private var icon: String {
        switch kind {
        case .continue: "arrow.forward"
        case .send: "arrow.up"
        case .stop: "stop.fill"
        }
    }

    private var help: String {
        switch kind {
        case .continue: "Let the story continue (Return)"
        case .send: "Send (Return)"
        case .stop: "Stop generating (Esc)"
        }
    }
}

private struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

private struct ScrollMetrics: Equatable {
    let offset: CGFloat
    let distanceFromBottom: CGFloat
}
