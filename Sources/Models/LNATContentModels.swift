import Foundation

public enum LnatTopic: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case mainConclusion = "Main Conclusion"
    case unstatedAssumptions = "Unstated Assumptions"
    case logicalFlaws = "Logical Flaws"
    case strengthenAndWeaken = "Strengthen & Weaken"
    case strictInference = "Strict Inference"
    case parallelReasoning = "Parallel Reasoning"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .mainConclusion: return "Conclusion"
        case .unstatedAssumptions: return "Assumptions"
        case .logicalFlaws: return "Flaws"
        case .strengthenAndWeaken: return "Strength/Weak"
        case .strictInference: return "Inference"
        case .parallelReasoning: return "Parallel"
        }
    }

    public var description: String {
        switch self {
        case .mainConclusion:
            return "Spot the central claim that every other part of the passage supports."
        case .unstatedAssumptions:
            return "Find the unspoken link required for the author's conclusion to hold."
        case .logicalFlaws:
            return "Identify why the evidence fails to justify the author's conclusion."
        case .strengthenAndWeaken:
            return "Judge which new fact most supports or undermines an argument."
        case .strictInference:
            return "Determine what must be true based strictly on the given text."
        case .parallelReasoning:
            return "Match the underlying logical pattern to a new argument."
        }
    }

    public var targetSkill: String {
        switch self {
        case .mainConclusion:
            return "Distinguish structural claim from supporting evidence"
        case .unstatedAssumptions:
            return "Apply the Negation Test to candidate assumptions"
        case .logicalFlaws:
            return "Name the structural gap between evidence and conclusion"
        case .strengthenAndWeaken:
            return "Attack or defend the assumption bridge, not background facts"
        case .strictInference:
            return "Guard against extreme quantifiers and outside assumptions"
        case .parallelReasoning:
            return "Map sufficient/necessary logic and quantifier scope"
        }
    }

    public var orderIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    public var nextTopic: LnatTopic {
        let all = Self.allCases
        let nextIndex = (orderIndex + 1) % all.count
        return all[nextIndex]
    }
}

public enum StoryCardDifficulty: String, Codable, Hashable, Sendable {
    case foundation = "Foundation"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

public enum StoryCardType: String, Codable, Hashable, Sendable {
    case primer
    case drill
}

public struct StorySlide1Hook: Codable, Hashable, Sendable {
    public let headline: String
    public let claimText: String
    public let ruleTakeaway: String
    public let wordCount: Int
}

public struct StorySlide2Spotlight: Codable, Hashable, Sendable {
    public let contextText: String
    public let highlightedSegment: String
    public let qualifierTag: String
    public let focusNote: String
    public let wordCount: Int
}

public struct StorySlide3Drill: Codable, Hashable, Sendable {
    public let questionId: String
    public let stem: String
    public let options: [String]
    public let correctIndex: Int
    public let topic: LnatTopic
    public let trapLabels: [String]
}

public struct StorySlide3WorkedExample: Codable, Hashable, Sendable {
    public let argumentText: String
    public let highlightedSegment: String
    public let highlightLabel: String
    public let annotation: String
    public let wordCount: Int
}

public struct StorySlide4Breakdown: Codable, Hashable, Sendable {
    public let logicSummary: String
    public let primaryTrap: String
    public let optionBreakdowns: [String]
    public let examTakeaway: String
}

public struct PrimerTrapItem: Codable, Identifiable, Hashable, Sendable {
    public let trapName: String
    public let howToSpot: String

    public var id: String { trapName }
}

public struct StorySlide4PrimerBreakdown: Codable, Hashable, Sendable {
    public let logicSummary: String
    public let commonTraps: [PrimerTrapItem]
    public let examTakeaway: String
}

public enum StoryCardPayload: Hashable, Sendable {
    case primer(workedExample: StorySlide3WorkedExample, breakdown: StorySlide4PrimerBreakdown)
    case drill(drill: StorySlide3Drill, breakdown: StorySlide4Breakdown)
}

public struct StoryCard: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let cardNumber: Int
    public let cardType: StoryCardType
    public let topic: LnatTopic
    public let title: String
    public let difficulty: StoryCardDifficulty
    public let slide1_hook: StorySlide1Hook
    public let slide2_spotlight: StorySlide2Spotlight
    public let payload: StoryCardPayload

    private enum CodingKeys: String, CodingKey {
        case id
        case cardNumber
        case cardType
        case topic
        case title
        case difficulty
        case slide1_hook
        case slide2_spotlight
        case slide3_workedExample
        case slide3_drill
        case slide4_breakdown
    }

    public init(
        id: String,
        cardNumber: Int,
        cardType: StoryCardType,
        topic: LnatTopic,
        title: String,
        difficulty: StoryCardDifficulty,
        slide1_hook: StorySlide1Hook,
        slide2_spotlight: StorySlide2Spotlight,
        payload: StoryCardPayload
    ) {
        self.id = id
        self.cardNumber = cardNumber
        self.cardType = cardType
        self.topic = topic
        self.title = title
        self.difficulty = difficulty
        self.slide1_hook = slide1_hook
        self.slide2_spotlight = slide2_spotlight
        self.payload = payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        cardNumber = try container.decode(Int.self, forKey: .cardNumber)
        cardType = try container.decode(StoryCardType.self, forKey: .cardType)
        topic = try container.decode(LnatTopic.self, forKey: .topic)
        title = try container.decode(String.self, forKey: .title)
        difficulty = try container.decode(StoryCardDifficulty.self, forKey: .difficulty)
        slide1_hook = try container.decode(StorySlide1Hook.self, forKey: .slide1_hook)
        slide2_spotlight = try container.decode(StorySlide2Spotlight.self, forKey: .slide2_spotlight)

        switch cardType {
        case .primer:
            let workedExample = try container.decode(
                StorySlide3WorkedExample.self,
                forKey: .slide3_workedExample
            )
            let breakdown = try container.decode(
                StorySlide4PrimerBreakdown.self,
                forKey: .slide4_breakdown
            )
            payload = .primer(workedExample: workedExample, breakdown: breakdown)
        case .drill:
            let drill = try container.decode(StorySlide3Drill.self, forKey: .slide3_drill)
            let breakdown = try container.decode(
                StorySlide4Breakdown.self,
                forKey: .slide4_breakdown
            )
            payload = .drill(drill: drill, breakdown: breakdown)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cardNumber, forKey: .cardNumber)
        try container.encode(cardType, forKey: .cardType)
        try container.encode(topic, forKey: .topic)
        try container.encode(title, forKey: .title)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(slide1_hook, forKey: .slide1_hook)
        try container.encode(slide2_spotlight, forKey: .slide2_spotlight)

        switch payload {
        case let .primer(workedExample, breakdown):
            try container.encode(workedExample, forKey: .slide3_workedExample)
            try container.encode(breakdown, forKey: .slide4_breakdown)
        case let .drill(drill, breakdown):
            try container.encode(drill, forKey: .slide3_drill)
            try container.encode(breakdown, forKey: .slide4_breakdown)
        }
    }

    public var isPrimer: Bool {
        cardType == .primer
    }

    public var workedExample: StorySlide3WorkedExample? {
        if case let .primer(workedExample, _) = payload { return workedExample }
        return nil
    }

    public var primerBreakdown: StorySlide4PrimerBreakdown? {
        if case let .primer(_, breakdown) = payload { return breakdown }
        return nil
    }

    public var drill: StorySlide3Drill? {
        if case let .drill(drill, _) = payload { return drill }
        return nil
    }

    public var drillBreakdown: StorySlide4Breakdown? {
        if case let .drill(_, breakdown) = payload { return breakdown }
        return nil
    }
}

public enum MockPaperId: String, Codable, Hashable, Sendable {
    case paper1 = "paper-1"
    case paper2 = "paper-2"
}

public struct MockQuestion: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let passageId: String
    public let questionNumber: Int
    public let topic: LnatTopic
    public let prompt: String
    public let stem: String
    public let options: [String]
    public let correctIndex: Int
    public let trapLabels: [String?]
    public let explanation: String
}

public struct MockPassage: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let paperId: MockPaperId
    public let passageNumber: Int
    public let title: String
    public let subtitle: String
    public let category: String
    public let wordCount: Int
    public let recommendedMinutes: Int
    public let passage: String
    public let paragraphs: [String]
    public let duplicateOf: String?
    public let questions: [MockQuestion]
}

public struct SectionBPrompt: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let prompt: String
    public let category: String
    public let keyTension: String
}

public enum TelemetrySource: String, Codable, Hashable, Sendable {
    case feed
    case mock
}

public struct QuestionTelemetryDTO: Codable, Hashable, Sendable {
    public let id: String?
    public let questionId: String
    public let topic: LnatTopic
    public let isCorrect: Bool
    public let timeSpentMs: Int
    public let selectedTrap: String?
    public let selectedOptionIndex: Int?
    public let source: TelemetrySource
    public let timestamp: Int64

    public init(
        id: String? = nil,
        questionId: String,
        topic: LnatTopic,
        isCorrect: Bool,
        timeSpentMs: Int,
        selectedTrap: String?,
        selectedOptionIndex: Int? = nil,
        source: TelemetrySource,
        timestamp: Int64
    ) {
        self.id = id
        self.questionId = questionId
        self.topic = topic
        self.isCorrect = isCorrect
        self.timeSpentMs = timeSpentMs
        self.selectedTrap = selectedTrap
        self.selectedOptionIndex = selectedOptionIndex
        self.source = source
        self.timestamp = timestamp
    }
}

public struct MockExamSessionDTO: Codable, Hashable, Sendable {
    public let id: String
    public let startedAt: Int64
    public let completedAt: Int64?
    public let passageIds: [String]
    public let answers: [String: Int]
    public let flaggedQuestionIds: [String]
    public let timeSpentByQuestionMs: [String: Int]
    public let totalElapsedMs: Int
    public let score: Int?
    public let totalQuestions: Int
    public let status: String
}

public struct SectionBOutlineDTO: Codable, Hashable, Sendable {
    public let id: String
    public let promptId: String
    public let promptText: String
    public let thesis: String
    public let point1: String
    public let point2: String
    public let counterargument: String
    public let rebuttal: String
    public let propositionPoints: [String]
    public let rebuttalAndSynthesis: String
    public let conclusionHook: String
    public let durationSeconds: Int
    public let createdAt: Int64
    public let updatedAt: Int64
}

public struct BackupPayload: Codable, Sendable {
    public let version: Int
    public let app: String
    public let exportedAt: String
    public let telemetry: [QuestionTelemetryDTO]
    public let mockSessions: [MockExamSessionDTO]
    public let sectionBOutlines: [SectionBOutlineDTO]
    public let completedCardIds: [String]

    public init(
        version: Int = 1,
        app: String = "LNAT Forge",
        exportedAt: String,
        telemetry: [QuestionTelemetryDTO],
        mockSessions: [MockExamSessionDTO],
        sectionBOutlines: [SectionBOutlineDTO],
        completedCardIds: [String]
    ) {
        self.version = version
        self.app = app
        self.exportedAt = exportedAt
        self.telemetry = telemetry
        self.mockSessions = mockSessions
        self.sectionBOutlines = sectionBOutlines
        self.completedCardIds = completedCardIds
    }
}
