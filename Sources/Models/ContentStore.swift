import Foundation

public final class ContentStore: Sendable {
    public static let shared = ContentStore()

    public let storyDeck: [StoryCard]
    public let mockPassages: [MockPassage]
    public let sectionBPrompts: [SectionBPrompt]

    public let primerCardIds: Set<String>
    public let validGradedQuestionIds: Set<String>
    public let passageIdSet: Set<String>
    public let uniquePassages: [MockPassage]
    public let passagesById: [String: MockPassage]
    public let sectionBCategories: [String]

    private init(
        storyDeck: [StoryCard],
        mockPassages: [MockPassage],
        sectionBPrompts: [SectionBPrompt]
    ) {
        self.storyDeck = storyDeck
        self.mockPassages = mockPassages
        self.sectionBPrompts = sectionBPrompts

        self.primerCardIds = Set(storyDeck.filter { $0.isPrimer }.map(\.id))

        var validIds = Set<String>()
        for card in storyDeck {
            if let drill = card.drill {
                validIds.insert(drill.questionId)
                validIds.insert(card.id)
            }
        }
        for passage in mockPassages {
            for question in passage.questions {
                validIds.insert(question.id)
            }
        }
        self.validGradedQuestionIds = validIds

        self.passageIdSet = Set(mockPassages.map(\.id))
        self.uniquePassages = mockPassages.filter { $0.duplicateOf == nil }
        self.passagesById = Dictionary(uniqueKeysWithValues: mockPassages.map { ($0.id, $0) })
        self.sectionBCategories = Self.orderedCategories(from: sectionBPrompts)
    }

    public convenience init(bundle: Bundle = .main) {
        let deck = Self.loadJSON([StoryCard].self, resource: "storyDeck", bundle: bundle) ?? []
        let passages = Self.loadJSON([MockPassage].self, resource: "mockTests", bundle: bundle) ?? []
        let prompts = Self.loadJSON([SectionBPrompt].self, resource: "section-b-prompts", bundle: bundle) ?? []
        self.init(storyDeck: deck, mockPassages: passages, sectionBPrompts: prompts)
    }

    public convenience init(resourceDirectoryURL: URL) throws {
        let decoder = JSONDecoder()
        let deckData = try Data(contentsOf: resourceDirectoryURL.appendingPathComponent("storyDeck.json"))
        let passagesData = try Data(contentsOf: resourceDirectoryURL.appendingPathComponent("mockTests.json"))
        let promptsData = try Data(contentsOf: resourceDirectoryURL.appendingPathComponent("section-b-prompts.json"))

        let deck = try decoder.decode([StoryCard].self, from: deckData)
        let passages = try decoder.decode([MockPassage].self, from: passagesData)
        let prompts = try decoder.decode([SectionBPrompt].self, from: promptsData)
        self.init(storyDeck: deck, mockPassages: passages, sectionBPrompts: prompts)
    }

    public func cards(for topic: LnatTopic) -> [StoryCard] {
        storyDeck.filter { $0.topic == topic }
    }

    private static func orderedCategories(from prompts: [SectionBPrompt]) -> [String] {
        let preferred = ["Law & Ethics", "Politics & Society", "Economics & Tech", "Culture & Rights"]
        let present = Set(prompts.map(\.category))
        var result = preferred.filter { present.contains($0) }
        for cat in prompts.map(\.category) where !result.contains(cat) {
            result.append(cat)
        }
        return result
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, resource: String, bundle: Bundle) -> T? {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
