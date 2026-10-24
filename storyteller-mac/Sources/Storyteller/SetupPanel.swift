import SwiftUI

struct SetupPanel: View {
    let id: UUID
    let onClose: () -> Void
    @Environment(Store.self) private var store
    @State private var tab = Tab.plot
    @Namespace private var underline

    enum Tab: String, CaseIterable { case plot = "Plot", cards = "Cards", settings = "Settings" }

    var body: some View {
        let adv = store.binding(id)
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Button {
                        withAnimation(.snappy(duration: 0.22)) { tab = t }
                    } label: {
                        HStack(spacing: 5) {
                            Text(t.rawValue).font(.system(size: 13, weight: .medium))
                            if t == .cards {
                                Text("\(adv.wrappedValue.cards.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                            }
                        }
                        .foregroundStyle(tab == t ? Theme.text : Theme.secondary)
                        .frame(height: 46)
                        .overlay(alignment: .bottom) {
                            if tab == t {
                                Capsule().fill(Theme.accent).frame(height: 2)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                IconButton(icon: "sidebar.right", help: "Hide story setup", size: 28, action: onClose)
            }
            .padding(.horizontal, 18)
            .background(Color.clear.contentShape(Rectangle()).windowDraggable())
            .overlay(alignment: .bottom) { Theme.hairline.frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch tab {
                    case .plot: PlotTab(adv: adv)
                    case .cards: CardsTab(adv: adv)
                    case .settings: SettingsTab(adv: adv)
                    }
                }
                .padding(18)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.never)
        }
        .background(Theme.sidebar)
    }
}

private struct Field<Content: View>: View {
    let title: String
    var hint: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(title: title, hint: hint)
            content
        }
    }
}

// MARK: - Plot

private struct PlotTab: View {
    @Binding var adv: Adventure

    var body: some View {
        Field(title: "Title") { InputField(placeholder: "Untitled", text: $adv.title) }
        Field(title: "AI Instructions", hint: "The system prompt — how the narrator behaves.") {
            TextArea(text: $adv.aiInstructions, minHeight: 150)
            if adv.aiInstructions != Presets.defaultInstructions {
                Button("Reset to default") { adv.aiInstructions = Presets.defaultInstructions }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            AppendedRules(adv: adv)
        }
        Field(title: "Plot Essentials", hint: "Always remembered: who you are, the world, the goal.") {
            TextArea(text: $adv.plotEssentials, placeholder: "You are…", minHeight: 100)
        }
        Field(title: "Story Summary", hint: "What happened so far, for long stories.") {
            TextArea(text: $adv.summary, placeholder: "Earlier, you…", minHeight: 80)
        }
        Field(title: "Author's Note", hint: "Whispered to the AI right before it writes.") {
            TextArea(text: $adv.authorsNote, placeholder: "Genre, tone, writing style…", minHeight: 56)
        }
    }
}

// MARK: - Cards

private struct CardsTab: View {
    @Binding var adv: Adventure
    @State private var expanded: UUID?
    @State private var hoverAdd = false

    var body: some View {
        let active = Set(Prompt.activeCards(adv).map(\.id))
        VStack(alignment: .leading, spacing: 12) {
            Text("Cards reach the AI only when a trigger word appears in recent story text — keeping prompts short and fast.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .lineSpacing(2)

            Button {
                let card = StoryCard(name: "")
                withAnimation(.snappy(duration: 0.2)) {
                    adv.cards.insert(card, at: 0)
                    expanded = card.id
                }
            } label: {
                Label("New card", systemImage: "plus")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(hoverAdd ? Theme.accent : Theme.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(hoverAdd ? Theme.accent.opacity(0.5) : Color.white.opacity(0.12)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hoverAdd = $0 }

            ForEach($adv.cards) { $card in
                CardRow(card: $card, isActive: active.contains(card.id), expanded: expanded == card.id) {
                    withAnimation(.snappy(duration: 0.22)) { expanded = expanded == card.id ? nil : card.id }
                } onDelete: {
                    let cid = card.id
                    withAnimation(.snappy(duration: 0.2)) { adv.cards.removeAll { $0.id == cid } }
                }
            }
        }
    }
}

private struct CardRow: View {
    @Binding var card: StoryCard
    let isActive: Bool
    let expanded: Bool
    let toggle: () -> Void
    let onDelete: () -> Void
    @State private var hover = false

    var body: some View {
        let tint = Theme.color(for: card.type)
        VStack(alignment: .leading, spacing: 12) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 7).fill(tint.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(card.name.isEmpty ? "Unnamed card" : card.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(card.name.isEmpty ? Theme.secondary : Theme.text)
                            .lineLimit(1)
                        Text(card.type.rawValue.capitalized).font(.system(size: 11)).foregroundStyle(Theme.tertiary)
                    }
                    Spacer()
                    if isActive {
                        Text("Active")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent.opacity(0.12)))
                            .help("Included in the next AI turn")
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        InputField(placeholder: "Name", text: $card.name)
                        MenuField(options: CardType.allCases, selection: $card.type) { $0.rawValue.capitalized }
                            .frame(width: 118)
                    }
                    InputField(placeholder: "Triggers, comma separated", text: $card.keys)
                    TextArea(text: $card.entry, placeholder: "What the AI should know…", minHeight: 90)
                    HStack {
                        Toggle("Always include", isOn: $card.alwaysOn)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondary)
                        Spacer()
                        Button(action: onDelete) {
                            Label("Delete", systemImage: "trash").font(.system(size: 11.5, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(red: 1, green: 0.5, blue: 0.48))
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(hover || expanded ? Theme.surface2 : Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(expanded ? Color.white.opacity(0.1) : Theme.hairline))
        .onHover { hover = $0 }
    }

    private var icon: String {
        switch card.type {
        case .character: "person.fill"
        case .location: "mappin.and.ellipse"
        case .faction: "flag.fill"
        case .item: "shippingbox.fill"
        case .lore: "scroll.fill"
        }
    }
}

// MARK: - Settings

private struct SettingsTab: View {
    @Binding var adv: Adventure
    @Environment(Store.self) private var store

    var body: some View {
        let models = store.ollamaModels ?? []
        let options = models.contains(adv.settings.model) ? models : [adv.settings.model] + models
        Field(title: "Model", hint: "Any model installed in Ollama.") {
            MenuField(options: options, selection: $adv.settings.model) { $0 }
        }
        SliderRow(title: "Temperature", hint: "Higher is more creative and chaotic.",
                  value: $adv.settings.temperature, range: 0.1...1.5, step: 0.05, format: "%.2f")
        SliderRow(title: "Response length", hint: "Max tokens per AI turn.",
                  value: intBinding($adv.settings.maxTokens), range: 60...600, step: 20, format: "%.0f")
        StoryMemoryPicker(adv: $adv)
    }

    private func intBinding(_ b: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(b.wrappedValue) }, set: { b.wrappedValue = Int($0) })
    }
}

private struct SliderRow: View {
    let title: String
    let hint: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(title: title, hint: hint)
                Spacer()
                Text(String(format: format, value))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bg))
            }
            Slider(value: $value, in: range, step: step).controlSize(.small)
        }
    }
}

/// Context window choice, with how much story it holds and the RAM it costs.
private struct StoryMemoryPicker: View {
    @Binding var adv: Adventure
    @Environment(Store.self) private var store

    var body: some View {
        let info = store.modelInfos[adv.settings.model]
        let window = adv.settings.contextWindow
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Story memory", hint: "How much recent story the AI can see. More memory uses more RAM.")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
                ForEach(GenSettings.windowOptions, id: \.self) { option in
                    let selected = option == window
                    let tooBig = info.map { option > $0.maxContext } ?? false
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { adv.settings.contextWindow = option }
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(option / 1024)K").font(.system(size: 14, weight: .semibold))
                            Text(info.map { $0.ramBytes(context: option).gigabytes } ?? "–")
                                .font(.system(size: 10.5).monospacedDigit())
                                .foregroundStyle(selected ? Theme.accent.opacity(0.85) : Theme.tertiary)
                        }
                        .foregroundStyle(selected ? Theme.accent : Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Theme.accent.opacity(0.12) : Theme.bg))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Theme.accent.opacity(0.4) : Theme.hairline))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(tooBig)
                    .opacity(tooBig ? 0.35 : 1)
                }
            }

            // What the selection means in story terms and memory.
            let words = Int(Double(Prompt.historyBudget(adv)) * 0.75)
            VStack(alignment: .leading, spacing: 8) {
                Row(icon: "text.book.closed", text: "Holds about **\(rounded(words)) words** of recent story (~\(max(1, words / 200)) turns).")
                if let info {
                    Row(icon: "memorychip", text: "≈ **\(info.ramBytes(context: window).gigabytes) RAM**: model \(info.fileBytes.gigabytes) + memory \((info.kvBytesPerToken * Int64(window)).gigabytes).")
                    if let loaded = store.loadedModels[adv.settings.model], let ctx = loaded.context {
                        Row(icon: "gauge.with.dots.needle.33percent",
                            text: ctx == window
                                ? "Ollama is using **\(loaded.bytes.gigabytes)** right now."
                                : "Loaded now at \(ctx / 1024)K (\(loaded.bytes.gigabytes)). Reloads at \(window / 1024)K on the next turn.")
                    }
                } else {
                    Row(icon: "memorychip", text: "RAM estimate unavailable — is Ollama running?")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg.opacity(0.6)))
        }
        .task(id: adv.settings.model) { store.refreshMemoryInfo(model: adv.settings.model) }
        .onChange(of: store.generating.isEmpty) { store.refreshMemoryInfo(model: adv.settings.model) }
    }

    private func rounded(_ n: Int) -> String {
        n >= 1000 ? (Double(n) / 1000).formatted(.number.precision(.fractionLength(1))) + "k" : "\(n)"
    }

    private struct Row: View {
        let icon: String
        let text: LocalizedStringKey

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(Theme.secondary).frame(width: 14)
                Text(text).font(.system(size: 12)).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Shows the text Storyteller adds after the AI Instructions, plus a full-prompt preview.
private struct AppendedRules: View {
    let adv: Adventure
    @State private var expanded = false
    @State private var showPrompt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle").font(.system(size: 11))
                        Text("Added automatically: pacing rules")
                            .font(.system(size: 11.5, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .foregroundStyle(Theme.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Sent after your AI Instructions on every turn")
                Spacer()
                Button("Full prompt…") { showPrompt = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .help("See everything the next turn sends to the AI")
            }
            if expanded {
                Text(Prompt.pacingRules(adv))
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Color.white.opacity(0.12)))
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showPrompt) { PromptPreview(adv: adv) }
    }
}

/// Every message the next AI turn will send, exactly as built.
private struct PromptPreview: View {
    let adv: Adventure
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let messages = Prompt.build(adv)
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Full prompt").font(.system(size: 15, weight: .semibold))
                    Text("What the next turn sends to \(adv.settings.model) · \(Prompt.usage(adv, scale: store.tokenScale[adv.id]).total.formatted()) tokens incl. reply")
                        .font(.system(size: 11.5)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .overlay(alignment: .bottom) { Theme.hairline.frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, m in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(label(m.role))
                                .font(.system(size: 10.5, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(color(m.role))
                            Text(m.content)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.text.opacity(0.9))
                                .lineSpacing(2)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline))
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 640, height: 620)
        .background(Theme.sidebar)
    }

    private func label(_ role: String) -> String {
        switch role {
        case "system": "SYSTEM"
        case "assistant": "AI"
        default: "YOU"
        }
    }

    private func color(_ role: String) -> Color {
        switch role {
        case "system": Theme.color(for: .faction)
        case "assistant": Theme.secondary
        default: Theme.accent
        }
    }
}
