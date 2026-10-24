import Foundation

enum ActionType: String, Codable, CaseIterable {
    /// `guide` is a composer mode only: it directs the next AI passage and is never stored as an action.
    case `do`, say, story, guide, ai

    var label: String {
        switch self {
        case .do: "Do"
        case .say: "Say"
        case .story: "Story"
        case .guide: "Guide"
        case .ai: "AI"
        }
    }

    var hint: String {
        switch self {
        case .do: "What do you do?"
        case .say: "What do you say?"
        case .guide: "What should happen next? e.g. a stranger interrupts with bad news"
        default: "Write what happens next…"
        }
    }
}

struct StoryAction: Codable, Identifiable, Equatable {
    var id = UUID()
    var type: ActionType
    var text: String
    /// For AI passages: the Guide direction it was written with (reused on Retry).
    var guide: String?
}

enum CardType: String, Codable, CaseIterable {
    case character, location, faction, item, lore
}

struct StoryCard: Codable, Identifiable, Equatable {
    var id = UUID()
    var type: CardType = .character
    var name: String
    /// Comma-separated trigger words. Empty = uses the name.
    var keys: String = ""
    var entry: String = ""
    var alwaysOn = false
}

struct GenSettings: Codable, Equatable {
    var model = "hermes3:3b"
    var temperature = 0.85
    var maxTokens = 220
    /// Context window in tokens (Ollama's num_ctx). Story history fills whatever is left.
    var contextWindow = 8192

    static let windowOptions = [4096, 8192, 16384, 32768]

    init() {}

    // Tolerates files saved before a field existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GenSettings()
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? d.model
        temperature = try c.decodeIfPresent(Double.self, forKey: .temperature) ?? d.temperature
        maxTokens = try c.decodeIfPresent(Int.self, forKey: .maxTokens) ?? d.maxTokens
        contextWindow = try c.decodeIfPresent(Int.self, forKey: .contextWindow) ?? d.contextWindow
    }
}

struct Adventure: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var createdAt = Date()
    var updatedAt = Date()
    var actions: [StoryAction] = []
    var aiInstructions = Presets.defaultInstructions
    var plotEssentials = ""
    var summary = ""
    var authorsNote = ""
    var cards: [StoryCard] = []
    var settings = GenSettings()
    /// Unsent composer text, restored after a quit or crash.
    var draft = ""
    var draftMode: ActionType = .do
}

extension Adventure {
    // Tolerates files saved before a field existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(title: try c.decodeIfPresent(String.self, forKey: .title) ?? "")
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? id
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? createdAt
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? updatedAt
        actions = try c.decodeIfPresent([StoryAction].self, forKey: .actions) ?? []
        aiInstructions = try c.decodeIfPresent(String.self, forKey: .aiInstructions) ?? aiInstructions
        plotEssentials = try c.decodeIfPresent(String.self, forKey: .plotEssentials) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        authorsNote = try c.decodeIfPresent(String.self, forKey: .authorsNote) ?? ""
        cards = try c.decodeIfPresent([StoryCard].self, forKey: .cards) ?? []
        settings = try c.decodeIfPresent(GenSettings.self, forKey: .settings) ?? GenSettings()
        draft = try c.decodeIfPresent(String.self, forKey: .draft) ?? ""
        draftMode = try c.decodeIfPresent(ActionType.self, forKey: .draftMode) ?? .do
    }
}
