import Foundation
import SwiftUI

/// All app state. Each adventure is saved as its own JSON file in `dir`.
@MainActor @Observable
final class Store {
    var adventures: [Adventure] = []
    var selection: UUID?
    var generating: Set<UUID> = []
    var errors: [UUID: String] = [:]
    /// nil = not checked yet, empty = Ollama unreachable.
    var ollamaModels: [String]?
    /// Architecture info per model name, for RAM estimates.
    var modelInfos: [String: ModelInfo] = [:]
    /// Per story: Ollama's exact prompt tokens ÷ our estimate, from the latest measurement.
    var tokenScale: [UUID: Double] = [:]
    /// What Ollama currently has in memory.
    var loadedModels: [String: LoadedModel] = [:]

    private(set) var dir: URL
    static let dirKey = "storiesDir"
    @ObservationIgnored private var tasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var redoStacks: [UUID: [StoryAction]] = [:]
    @ObservationIgnored private var saveTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var filenames: [UUID: String] = [:]

    init() {
        if let custom = ProcessInfo.processInfo.environment["STORYTELLER_DIR"] ?? UserDefaults.standard.string(forKey: Self.dirKey) {
            dir = URL(fileURLWithPath: custom)
        } else {
            dir = URL.applicationSupportDirectory.appending(path: "Storyteller/Stories")
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
        refreshModels()
    }

    /// Switches to another stories folder and loads what's in it.
    func changeDirectory(to url: URL) {
        for id in tasks.keys { stop(id) }
        flushSaves()
        UserDefaults.standard.set(url.path, forKey: Self.dirKey)
        dir = url
        adventures = []
        filenames = [:]
        redoStacks = [:]
        errors = [:]
        load()
    }

    func refreshModels() {
        Task { ollamaModels = await Ollama.models() }
    }

    private func calibrate(_ id: UUID, actual: Int?, messages: [ChatMessage]) {
        let estimate = Prompt.estimate(messages)
        guard let actual, actual > 0, estimate > 0 else { return }
        tokenScale[id] = Double(actual) / Double(estimate)
    }

    /// Measures a story's prompt with Ollama once, if we haven't yet (e.g. on opening it).
    func measureTokens(_ id: UUID) {
        guard tokenScale[id] == nil, !generating.contains(id), let adv = adventure(id), !adv.actions.isEmpty else { return }
        let messages = Prompt.build(adv)
        Task {
            let actual = await Ollama.countPromptTokens(messages, settings: adv.settings)
            if tokenScale[id] == nil { calibrate(id, actual: actual, messages: messages) }
        }
    }

    func refreshMemoryInfo(model: String) {
        Task {
            if modelInfos[model] == nil, let info = await Ollama.modelInfo(model) { modelInfos[model] = info }
            loadedModels = await Ollama.loaded()
        }
    }

    // MARK: Persistence

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let adv = try? Self.decoder.decode(Adventure.self, from: data) else { continue }
            adventures.append(adv)
            filenames[adv.id] = url.lastPathComponent
        }
        adventures.sort { $0.updatedAt > $1.updatedAt }
        selection = adventures.first?.id
    }

    private func filename(for adv: Adventure) -> String {
        let slug = adv.title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "\(slug.isEmpty ? "story" : String(slug.prefix(40)))-\(adv.id.uuidString.prefix(8).lowercased()).json"
    }

    private func scheduleSave(_ id: UUID) {
        saveTasks[id]?.cancel()
        saveTasks[id] = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            save(id)
        }
    }

    private func save(_ id: UUID) {
        guard let adv = adventure(id), let data = try? Self.encoder.encode(adv) else { return }
        let name = filename(for: adv)
        try? data.write(to: dir.appending(path: name), options: .atomic)
        if let old = filenames[id], old != name { try? FileManager.default.removeItem(at: dir.appending(path: old)) }
        filenames[id] = name
    }

    // MARK: Access

    func adventure(_ id: UUID) -> Adventure? { adventures.first { $0.id == id } }

    func update(_ id: UUID, _ fn: (inout Adventure) -> Void) {
        guard let i = adventures.firstIndex(where: { $0.id == id }) else { return }
        fn(&adventures[i])
        adventures[i].updatedAt = .now
        scheduleSave(id)
    }

    /// Saves composer text without marking the story as updated.
    func setDraft(_ id: UUID, text: String, mode: ActionType) {
        guard let i = adventures.firstIndex(where: { $0.id == id }),
              adventures[i].draft != text || adventures[i].draftMode != mode else { return }
        adventures[i].draft = text
        adventures[i].draftMode = mode
        scheduleSave(id)
    }

    /// Writes any pending saves immediately (called when the app quits).
    func flushSaves() {
        for (id, task) in saveTasks {
            task.cancel()
            save(id)
        }
        saveTasks.removeAll()
    }

    func binding(_ id: UUID) -> Binding<Adventure> {
        Binding(
            get: { self.adventure(id) ?? Adventure(title: "") },
            set: { new in self.update(id) { $0 = new } }
        )
    }

    // MARK: Adventures

    func create(_ preset: Preset) {
        let adv = preset.makeAdventure()
        adventures.insert(adv, at: 0)
        selection = adv.id
        save(adv.id)
    }

    func duplicate(_ id: UUID) {
        guard var copy = adventure(id) else { return }
        copy.id = UUID()
        copy.title += " (copy)"
        copy.createdAt = .now
        adventures.insert(copy, at: 0)
        selection = copy.id
        save(copy.id)
    }

    func delete(_ id: UUID) {
        stop(id)
        saveTasks[id]?.cancel()
        if let name = filenames.removeValue(forKey: id) { try? FileManager.default.removeItem(at: dir.appending(path: name)) }
        adventures.removeAll { $0.id == id }
        if selection == id { selection = adventures.first?.id }
    }

    // MARK: Story actions

    func submit(_ id: UUID, type: ActionType, text: String) {
        guard !generating.contains(id) else { return }
        if type == .guide {
            generate(id, guide: text.trimmed.isEmpty ? nil : text.trimmed)
            return
        }
        if !text.trimmed.isEmpty {
            redoStacks[id] = []
            update(id) { $0.actions.append(StoryAction(type: type, text: text.trimmed)) }
        }
        generate(id)
    }

    func retry(_ id: UUID) {
        guard !generating.contains(id) else { return }
        var guide: String?
        if let last = adventure(id)?.actions.last, last.type == .ai {
            guide = last.guide
            update(id) { $0.actions.removeLast() }
        }
        generate(id, guide: guide)
    }

    func undo(_ id: UUID) {
        stop(id)
        guard let last = adventure(id)?.actions.last else { return }
        redoStacks[id, default: []].append(last)
        update(id) { $0.actions.removeLast() }
    }

    func redo(_ id: UUID) {
        guard let next = redoStacks[id]?.popLast() else { return }
        update(id) { $0.actions.append(next) }
    }

    func canRedo(_ id: UUID) -> Bool { !(redoStacks[id]?.isEmpty ?? true) }

    func editAction(_ id: UUID, actionID: UUID, text: String) {
        update(id) { adv in
            if let i = adv.actions.firstIndex(where: { $0.id == actionID }) { adv.actions[i].text = text }
        }
    }

    func deleteAction(_ id: UUID, actionID: UUID) {
        update(id) { $0.actions.removeAll { $0.id == actionID } }
    }

    func stop(_ id: UUID) { tasks[id]?.cancel() }

    private func generate(_ id: UUID, guide: String? = nil) {
        guard let adv = adventure(id), !generating.contains(id) else { return }
        let messages = Prompt.build(adv, guide: guide)
        let aiID = UUID()
        update(id) { $0.actions.append(StoryAction(id: aiID, type: .ai, text: "", guide: guide)) }
        generating.insert(id)
        errors[id] = nil

        tasks[id] = Task {
            var raw = ""
            var failure: String?
            var cutOff = false
            do {
                for try await event in Ollama.stream(messages, settings: adv.settings) {
                    switch event {
                    case .text(let chunk):
                        raw += chunk
                        editAction(id, actionID: aiID, text: String(raw.drop(while: \.isWhitespace)))
                    case .done(let hitLimit, let promptTokens):
                        cutOff = hitLimit
                        calibrate(id, actual: promptTokens, messages: messages)
                    }
                }
            } catch {
                if Task.isCancelled { cutOff = true } else { failure = Ollama.describe(error) }
            }
            // Stopped at the length cap (or by Stop): drop the unfinished last sentence.
            var final = Prompt.clean(raw)
            if cutOff { final = Prompt.trimToLastSentence(final) }
            if final.isEmpty { deleteAction(id, actionID: aiID) } else { editAction(id, actionID: aiID, text: final) }
            generating.remove(id)
            errors[id] = failure
            tasks[id] = nil
        }
    }
}
