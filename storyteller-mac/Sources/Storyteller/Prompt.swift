import Foundation

struct ChatMessage {
    let role: String
    var content: String
}

enum Prompt {
    private static let endPunct: Set<Character> = [".", "!", "?", "…", "\"", "'", ")", "]"]

    /// Turns a raw player input into the displayed/prompted text, AI Dungeon style.
    static func format(_ a: StoryAction) -> String {
        let t = a.text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch a.type {
        case .do:
            var s = secondPerson(t)
            if s.range(of: #"^you\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
                s = "Y" + s.dropFirst()
            } else {
                s = "You " + s.prefix(1).lowercased() + s.dropFirst()
            }
            if let last = s.last, !endPunct.contains(last) { s += "." }
            return "> " + s
        case .say:
            var q = t.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
            if let last = q.last, !endPunct.contains(last) { q += "." }
            return "> You say \"\(q)\""
        default:
            return t
        }
    }

    private static let pronouns: [String: String] = [
        "i'm": "you're", "i've": "you've", "i'll": "you'll", "i'd": "you'd",
        "i am": "you are", "i was": "you were", "i": "you",
        "me": "you", "my": "your", "mine": "yours", "myself": "yourself",
    ]
    private static let nounMarkers: Set<String> = ["the", "a", "an", "this", "that", "gold", "coal", "old", "abandoned", "land", "silver", "iron"]
    private static let pronounRegex = try! NSRegularExpression(
        pattern: #"\b(i['’](?:m|ve|ll|d)|i am|i was|i|me|my|mine|myself)\b"#,
        options: [.caseInsensitive])

    /// "I look outside. I feel sad." → "you look outside. You feel sad."
    static func secondPerson(_ text: String) -> String {
        let ns = NSMutableString(string: text)
        for m in pronounRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let word = ns.substring(with: m.range)
            let key = word.lowercased().replacingOccurrences(of: "’", with: "'")
            guard var rep = pronouns[key] else { continue }
            // "the mine", "a gold mine" are places, not "yours".
            if key == "mine", let prev = ns.substring(to: m.range.location).split(whereSeparator: \.isWhitespace).last,
               nounMarkers.contains(prev.lowercased()) { continue }
            if word.contains("’") { rep = rep.replacingOccurrences(of: "'", with: "’") }
            // Capitalize at the start of a sentence.
            let before = ns.substring(to: m.range.location).trimmingCharacters(in: .whitespaces)
            if before.isEmpty || ".!?\n".contains(before.last!) { rep = rep.prefix(1).uppercased() + rep.dropFirst() }
            ns.replaceCharacters(in: m.range, with: rep)
        }
        return ns as String
    }

    /// Cards whose trigger words appear in the last few passages.
    static func activeCards(_ adv: Adventure) -> [StoryCard] {
        let recent = adv.actions.filter { !$0.text.trimmed.isEmpty }.suffix(6)
        let text = recent.map(\.text).joined(separator: "\n").lowercased()
        return adv.cards.filter { c in
            if c.alwaysOn { return true }
            let src = c.keys.trimmingCharacters(in: .whitespaces).isEmpty ? c.name : c.keys
            return src.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .contains { !$0.isEmpty && text.contains($0) }
        }
    }

    /// Tokens used by everything except story history.
    private static func fixedTokens(_ adv: Adventure) -> Int {
        tokens(adv.aiInstructions) + tokens(adv.plotEssentials + adv.summary + adv.authorsNote)
            + activeCards(adv).reduce(0) { $0 + tokens($1.name + $1.entry) + 4 }
    }

    /// Kept free for chat formatting and estimate error.
    static let safetyMargin = 300

    /// Tokens left for story history in a given context window.
    static func historyBudget(_ adv: Adventure, window: Int? = nil) -> Int {
        max(0, (window ?? adv.settings.contextWindow) - fixedTokens(adv) - adv.settings.tokenCap - safetyMargin)
    }

    /// The newest passages that fit in the history budget.
    private static func recentHistory(_ adv: Adventure) -> [StoryAction] {
        let budget = historyBudget(adv)
        var out: [StoryAction] = []
        var used = 0
        for a in adv.actions.reversed() where !a.text.trimmed.isEmpty {
            used += tokens(format(a)) + 4
            if used > budget && !out.isEmpty { break }
            out.insert(a, at: 0)
        }
        return out
    }

    static func build(_ adv: Adventure, guide: String? = nil) -> [ChatMessage] {
        let cards = activeCards(adv)
        var system = adv.aiInstructions.trimmed
        system += "\n\n" + pacingRules(adv)
        if !adv.plotEssentials.trimmed.isEmpty { system += "\n\n## Plot Essentials\n" + adv.plotEssentials.trimmed }
        if !adv.summary.trimmed.isEmpty { system += "\n\n## Story So Far\n" + adv.summary.trimmed }
        if !cards.isEmpty {
            system += "\n\n## World Info\n" + cards.map { "[\($0.type.rawValue): \($0.name)] \($0.entry.trimmed)" }.joined(separator: "\n")
        }

        var messages = [ChatMessage(role: "system", content: system)]
        for a in recentHistory(adv) {
            let role = a.type == .ai ? "assistant" : "user"
            if messages[messages.count - 1].role == role {
                messages[messages.count - 1].content += "\n\n" + format(a)
            } else {
                messages.append(ChatMessage(role: role, content: format(a)))
            }
        }
        // If the AI spoke last (or nothing yet), nudge it to keep going.
        if messages.last?.role != "user" { messages.append(ChatMessage(role: "user", content: "Continue the story.")) }
        if !adv.authorsNote.trimmed.isEmpty {
            messages[messages.count - 1].content += "\n\n[Author's note: \(adv.authorsNote.trimmed)]"
        }
        if let guide, !guide.trimmed.isEmpty {
            messages[messages.count - 1].content +=
                "\n\n[Direction for your next passage: \(guide.trimmed). Make this happen naturally in the story, in your own words.]"
        }
        return messages
    }

    /// Rough token estimate (~4 characters per token for English).
    static func tokens(_ s: String) -> Int { (s.count + 3) / 4 }

    /// Estimated context the next AI turn will use, split by source.
    static func usage(_ adv: Adventure) -> ContextUsage {
        let history = recentHistory(adv)
        return ContextUsage(
            instructions: tokens(adv.aiInstructions),
            plot: tokens(adv.plotEssentials + adv.summary + adv.authorsNote),
            cards: activeCards(adv).reduce(0) { $0 + tokens($1.name + $1.entry) + 4 },
            history: history.reduce(0) { $0 + tokens(format($1)) + 4 },
            reserve: adv.settings.tokenCap,
            window: adv.settings.contextWindow,
            turnsIncluded: history.count,
            turnsTotal: adv.actions.filter { !$0.text.trimmed.isEmpty }.count
        )
    }

    /// Added to every story's system prompt: keeps passages short and open-ended. Small models
    /// otherwise like to wrap scenes up ("…as the days passed, hope lingered.").
    static func pacingRules(_ adv: Adventure) -> String {
        """
        ## Pacing
        - Write about \(targetWords(adv)) words.
        - Stay in the current moment. Never summarize, reflect on the journey, or skip ahead in time.
        - Do not wrap up the scene or write a closing line. The story is ongoing.
        - Stop in the middle of the action, at a point where the player must react: a character speaks \
        to them, something happens, or a choice appears. End on a complete sentence.
        """
    }

    /// Word target that leaves headroom under the token cap (~0.75 words per token, minus a margin)
    /// so the model wraps up naturally instead of being cut off.
    static func targetWords(_ adv: Adventure) -> Int {
        max(20, Int((Double(adv.settings.maxTokens) * 0.55 / 10).rounded()) * 10)
    }

    /// Splits streaming text into finished sentences and the sentence still being written.
    /// Before the first sentence ends, everything counts as finished (nothing to dim yet).
    static func splitPendingSentence(_ text: String) -> (done: String, pending: String) {
        guard let r = text.range(of: #"[.!?…]["'”’)\]]*(?=[^.!?…]*$)"#, options: .regularExpression) else { return (text, "") }
        return (String(text[..<r.upperBound]), String(text[r.upperBound...]))
    }

    /// Cuts text back to its last complete sentence (keeping closing quotes/brackets).
    /// Leaves it unchanged if that would remove most of it.
    static func trimToLastSentence(_ text: String) -> String {
        guard let r = text.range(of: #"[.!?…]["'”’)\]]*(?=[^.!?…]*$)"#, options: .regularExpression) else { return text }
        let trimmed = String(text[..<r.upperBound])
        return trimmed.count >= text.count / 3 ? trimmed : text
    }

    /// Small models sometimes write the player's next turn; cut it off.
    static func clean(_ text: String) -> String {
        var t = String(text.drop(while: \.isWhitespace))
        if let r = t.range(of: #"\n\s*(>|\[Author)"#, options: .regularExpression) {
            t = String(t[..<r.lowerBound])
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct ContextUsage {
    var instructions: Int
    var plot: Int
    var cards: Int
    var history: Int
    /// Space kept free for the AI's reply.
    var reserve: Int
    var window: Int
    var turnsIncluded: Int
    var turnsTotal: Int

    var total: Int { instructions + plot + cards + history + reserve }
    var fraction: Double { min(Double(total) / Double(window), 1) }
}
