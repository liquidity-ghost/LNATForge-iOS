import Foundation
import SwiftData

private enum SwiftDataCoding {
    static func encodeJSON<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    static func decodeJSON<T: Decodable>(_ data: Data, fallback: T) -> T {
        guard !data.isEmpty else { return fallback }
        return (try? JSONDecoder().decode(T.self, from: data)) ?? fallback
    }
}

@Model
public final class QuestionAttempt {
    public var id: String
    public var questionId: String
    public var topicRaw: String
    public var isCorrect: Bool
    public var timeSpentMs: Int
    public var selectedTrap: String?
    public var selectedOptionIndex: Int?
    public var sourceRaw: String
    public var timestampMs: Int64

    public init(
        id: String = "tel-\(UUID().uuidString)",
        questionId: String,
        topic: LnatTopic,
        isCorrect: Bool,
        timeSpentMs: Int,
        selectedTrap: String?,
        selectedOptionIndex: Int? = nil,
        source: TelemetrySource,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.questionId = questionId
        self.topicRaw = topic.rawValue
        self.isCorrect = isCorrect
        self.timeSpentMs = timeSpentMs
        self.selectedTrap = selectedTrap
        self.selectedOptionIndex = selectedOptionIndex
        self.sourceRaw = source.rawValue
        self.timestampMs = timestampMs
    }

    public var topic: LnatTopic? {
        LnatTopic(rawValue: topicRaw)
    }

    public var source: TelemetrySource {
        TelemetrySource(rawValue: sourceRaw) ?? .feed
    }

    public func toDTO() -> QuestionTelemetryDTO? {
        guard let topic = topic else { return nil }
        return QuestionTelemetryDTO(
            id: id,
            questionId: questionId,
            topic: topic,
            isCorrect: isCorrect,
            timeSpentMs: timeSpentMs,
            selectedTrap: selectedTrap,
            selectedOptionIndex: selectedOptionIndex,
            source: source,
            timestamp: timestampMs
        )
    }
}

@Model
public final class MockSessionRecord {
    public var id: String
    public var startedAtMs: Int64
    public var completedAtMs: Int64?
    public var passageIdsData: Data
    public var answersData: Data
    public var flaggedQuestionIdsData: Data
    public var timeSpentByQuestionMsData: Data
    public var totalElapsedMs: Int
    public var score: Int?
    public var totalQuestions: Int
    public var status: String

    public init(
        id: String = "mock-\(Int64(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(5))",
        startedAtMs: Int64,
        completedAtMs: Int64?,
        passageIds: [String],
        answers: [String: Int],
        flaggedQuestionIds: [String],
        timeSpentByQuestionMs: [String: Int],
        totalElapsedMs: Int,
        score: Int?,
        totalQuestions: Int,
        status: String = "completed"
    ) {
        self.id = id
        self.startedAtMs = startedAtMs
        self.completedAtMs = completedAtMs
        self.passageIdsData = SwiftDataCoding.encodeJSON(passageIds)
        self.answersData = SwiftDataCoding.encodeJSON(answers)
        self.flaggedQuestionIdsData = SwiftDataCoding.encodeJSON(flaggedQuestionIds)
        self.timeSpentByQuestionMsData = SwiftDataCoding.encodeJSON(timeSpentByQuestionMs)
        self.totalElapsedMs = totalElapsedMs
        self.score = score
        self.totalQuestions = totalQuestions
        self.status = status
    }

    public var passageIds: [String] {
        get { SwiftDataCoding.decodeJSON(passageIdsData, fallback: []) }
        set { passageIdsData = SwiftDataCoding.encodeJSON(newValue) }
    }

    public var answers: [String: Int] {
        get { SwiftDataCoding.decodeJSON(answersData, fallback: [:]) }
        set { answersData = SwiftDataCoding.encodeJSON(newValue) }
    }

    public var flaggedQuestionIds: [String] {
        get { SwiftDataCoding.decodeJSON(flaggedQuestionIdsData, fallback: []) }
        set { flaggedQuestionIdsData = SwiftDataCoding.encodeJSON(newValue) }
    }

    public var timeSpentByQuestionMs: [String: Int] {
        get { SwiftDataCoding.decodeJSON(timeSpentByQuestionMsData, fallback: [:]) }
        set { timeSpentByQuestionMsData = SwiftDataCoding.encodeJSON(newValue) }
    }

    public var sessionTitle: String {
        let ids = passageIds
        if ids.count > 2 {
            let isPaper2 = ids.allSatisfy { $0.hasPrefix("p2-") }
            return isPaper2 ? "Official Test Version 2" : "Official Test Version 1"
        }
        return "Quick Session"
    }

    public func toDTO() -> MockExamSessionDTO {
        MockExamSessionDTO(
            id: id,
            startedAt: startedAtMs,
            completedAt: completedAtMs,
            passageIds: passageIds,
            answers: answers,
            flaggedQuestionIds: flaggedQuestionIds,
            timeSpentByQuestionMs: timeSpentByQuestionMs,
            totalElapsedMs: totalElapsedMs,
            score: score,
            totalQuestions: totalQuestions,
            status: status
        )
    }
}

@Model
public final class SavedOutline {
    public var id: String
    public var promptId: String
    public var promptText: String
    public var thesis: String
    public var point1: String
    public var point2: String
    public var counterargument: String
    public var rebuttal: String
    public var conclusionHook: String
    public var durationSeconds: Int
    public var createdAtMs: Int64
    public var updatedAtMs: Int64

    public init(
        id: String = "outline-\(Int64(Date().timeIntervalSince1970 * 1000))",
        promptId: String,
        promptText: String,
        thesis: String,
        point1: String,
        point2: String,
        counterargument: String,
        rebuttal: String,
        conclusionHook: String = "",
        durationSeconds: Int,
        createdAtMs: Int64,
        updatedAtMs: Int64
    ) {
        self.id = id
        self.promptId = promptId
        self.promptText = promptText
        self.thesis = thesis
        self.point1 = point1
        self.point2 = point2
        self.counterargument = counterargument
        self.rebuttal = rebuttal
        self.conclusionHook = conclusionHook
        self.durationSeconds = durationSeconds
        self.createdAtMs = createdAtMs
        self.updatedAtMs = updatedAtMs
    }

    public func toDTO() -> SectionBOutlineDTO {
        let points = [point1, point2].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let synthesis = [counterargument, rebuttal]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " — ")
        return SectionBOutlineDTO(
            id: id,
            promptId: promptId,
            promptText: promptText,
            thesis: thesis,
            point1: point1,
            point2: point2,
            counterargument: counterargument,
            rebuttal: rebuttal,
            propositionPoints: points,
            rebuttalAndSynthesis: synthesis,
            conclusionHook: conclusionHook,
            durationSeconds: durationSeconds,
            createdAt: createdAtMs,
            updatedAt: updatedAtMs
        )
    }
}

@Model
public final class CompletedCardRecord {
    public var cardId: String
    public var completedAtMs: Int64

    public init(
        cardId: String,
        completedAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.cardId = cardId
        self.completedAtMs = completedAtMs
    }
}
