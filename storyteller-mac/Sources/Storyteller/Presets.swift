import Foundation

struct Preset {
    let name: String
    let icon: String
    let blurb: String
    let title: String
    let opening: String
    let plotEssentials: String
    let authorsNote: String
    let cards: [StoryCard]

    func makeAdventure() -> Adventure {
        var a = Adventure(title: title)
        if !opening.isEmpty { a.actions = [StoryAction(type: .story, text: opening)] }
        a.plotEssentials = plotEssentials
        a.authorsNote = authorsNote
        a.cards = cards.map { var c = $0; c.id = UUID(); return c }
        return a
    }
}

enum Presets {
    static let defaultInstructions = """
    You are the narrator of an interactive story. The player controls the main character, referred to as "you".
    - Write in second person, present tense, with vivid but concise prose.
    - Continue the story naturally from the player's latest action. Describe consequences, the world, and other characters' reactions.
    - Never decide the player's actions, thoughts or dialogue beyond what they wrote.
    - Write 1-3 short paragraphs. Do not end with questions like "What do you do?".
    - Stay consistent with the plot essentials and world info.
    """

    static let all: [Preset] = [
        Preset(
            name: "Fantasy", icon: "shield.lefthalf.filled",
            blurb: "A wandering knight, a cursed kingdom, a dragon on the horizon.",
            title: "The Ashen Crown",
            opening: "You are Aldric, a knight without a lord, riding into the border town of Thornwick as the sun bleeds into the hills. The gates are barred, the watchtowers empty, and far to the north a column of black smoke rises from the mountains where the old dragon was said to sleep.",
            plotEssentials: "You are Aldric, a disgraced knight seeking redemption. The kingdom of Vael is ruled by Queen Maren, whose crown is cursed. A dragon named Sarvok has awakened in the northern peaks.",
            authorsNote: "Genre: dark fantasy. Tone: grim, atmospheric, hopeful undercurrent.",
            cards: [
                StoryCard(type: .character, name: "Sarvok", keys: "dragon, Sarvok", entry: "Sarvok is an ancient ash-grey dragon, cunning and weary, who speaks in riddles and despises the royal bloodline."),
                StoryCard(type: .location, name: "Thornwick", keys: "Thornwick, town", entry: "Thornwick is a walled border town of timber and slate, known for its tavern The Crooked Lantern and its paranoid militia."),
                StoryCard(type: .character, name: "Queen Maren", keys: "queen, Maren", entry: "Queen Maren is young, brilliant and slowly being consumed by the whispering curse of the Ashen Crown."),
            ]),
        Preset(
            name: "Sci‑Fi", icon: "sparkles",
            blurb: "Salvage crew, derelict ship, something still alive aboard.",
            title: "Drift of the Meridian",
            opening: "Your salvage tug docks with the derelict colony ship Meridian after eleven days of silence on every channel. Emergency lights pulse a slow red down the boarding corridor. Your helmet display reads breathable air, 4°C, and one faint heat signature three decks below.",
            plotEssentials: "You are Captain Jo Reyes of the salvage tug Kestrel. Your AI copilot is named HALE. The Meridian went missing 40 years ago carrying 3,000 colonists in cryosleep.",
            authorsNote: "Genre: sci-fi horror. Tone: tense, claustrophobic, slow-burn.",
            cards: [
                StoryCard(type: .character, name: "HALE", keys: "HALE, copilot, AI", entry: "HALE is the Kestrel's dry-humored AI copilot. It speaks through your helmet comms and is fiercely loyal but bound by salvage law."),
                StoryCard(type: .location, name: "Cryo Deck", keys: "cryo, pods, deck", entry: "The cryo deck holds 3,000 pods. Most are dark. Some have been opened from the inside."),
            ]),
        Preset(
            name: "Mystery", icon: "magnifyingglass",
            blurb: "1940s city, rain on neon, a client who's lying to you.",
            title: "Rain on Hollis Street",
            opening: "Rain is hammering the window of your third-floor office when the woman in the green coat walks in without knocking. She sets a photograph on your desk — a man you recognize, a man you watched them bury last spring. \"He called me last night,\" she says. \"I need you to find him.\"",
            plotEssentials: "You are Sam Calloway, a private detective in 1947 Port Avery. Your client calls herself Vivian Lake. The man in the photo is Eddie Marsh, a jazz pianist who supposedly died in a fire.",
            authorsNote: "Genre: noir mystery. Tone: moody, sharp dialogue, clues layered gradually.",
            cards: [
                StoryCard(type: .character, name: "Vivian Lake", keys: "Vivian, client, woman", entry: "Vivian Lake is poised and evasive. Her real name is Vera Marsh — Eddie's sister — and she owes money to the Castellano family."),
                StoryCard(type: .location, name: "The Blue Lantern", keys: "Blue Lantern, club, jazz", entry: "The Blue Lantern is a smoky jazz club on the docks where Eddie used to play. The bartender, Moe, knows more than he says."),
            ]),
        Preset(
            name: "Blank", icon: "pencil.line",
            blurb: "Start from nothing. Write your own opening.",
            title: "Untitled Story", opening: "", plotEssentials: "", authorsNote: "", cards: []),
    ]
}
