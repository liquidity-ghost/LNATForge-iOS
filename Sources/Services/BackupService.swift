import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

public struct LNATBackupDocument: Transferable, Sendable {
    public let filename: String
    public let jsonData: Data

    public init(filename: String, jsonData: Data) {
        self.filename = filename
        self.jsonData = jsonData
    }

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { document in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(document.filename)
            try document.jsonData.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
        .suggestedFileName { document in
            document.filename
        }
    }
}

public struct BackupImportSummary: Sendable {
    public let telemetryImported: Int
    public let mockSessionsImported: Int
    public let outlinesImported: Int
}

public enum BackupServiceError: LocalizedError {
    case invalidJSON
    case unrecognizedFormat

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON file. Please provide a valid LNAT Forge backup."
        case .unrecognizedFormat:
            return "Unrecognized backup format. Expected an LNAT Forge backup payload."
        }
    }
}

@MainActor
public enum BackupService {
    public static func exportJSON(
        attempts: [QuestionAttempt],
        mockSessions: [MockSessionRecord],
        outlines: [SavedOutline],
        completedCards: [CompletedCardRecord]
    ) throws -> Data {
        let telemetryDTOs = attempts
            .compactMap { $0.toDTO() }
            .sorted { $0.timestamp < $1.timestamp }
        let sessionDTOs = mockSessions
            .sorted { $0.startedAtMs > $1.startedAtMs }
            .map { $0.toDTO() }
        let outlineDTOs = outlines
            .sorted { $0.updatedAtMs > $1.updatedAtMs }
            .map { $0.toDTO() }
        let completedIds = Array(Set(completedCards.map(\.cardId))).sorted()

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload = BackupPayload(
            version: 1,
            app: "LNAT Forge",
            exportedAt: isoFormatter.string(from: Date()),
            telemetry: telemetryDTOs,
            mockSessions: sessionDTOs,
            sectionBOutlines: outlineDTOs,
            completedCardIds: completedIds
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    public static func makeBackupDocument(
        attempts: [QuestionAttempt],
        mockSessions: [MockSessionRecord],
        outlines: [SavedOutline],
        completedCards: [CompletedCardRecord]
    ) throws -> LNATBackupDocument {
        let data = try exportJSON(
            attempts: attempts,
            mockSessions: mockSessions,
            outlines: outlines,
            completedCards: completedCards
        )
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        return LNATBackupDocument(
            filename: "lnat-forge-backup-\(dateString).json",
            jsonData: data
        )
    }

    public static func importJSON(_ data: Data, into context: ModelContext) throws -> BackupImportSummary {
        let decoder = JSONDecoder()
        let payload: BackupPayload
        do {
            payload = try decoder.decode(BackupPayload.self, from: data)
        } catch {
            // Check if valid JSON with wrong app field
            if let rawObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (rawObj["app"] as? String) != "LNAT Forge" {
                throw BackupServiceError.unrecognizedFormat
            }
            throw BackupServiceError.invalidJSON
        }

        guard payload.app == "LNAT Forge" else {
            throw BackupServiceError.unrecognizedFormat
        }

        let existingAttempts = (try? context.fetch(FetchDescriptor<QuestionAttempt>())) ?? []
        var attemptById = Dictionary(existingAttempts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var telemetryImported = 0

        for item in payload.telemetry {
            let resolvedId = item.id ?? "tel-\(UUID().uuidString)"
            if let existing = attemptById[resolvedId] {
                existing.questionId = item.questionId
                existing.topicRaw = item.topic.rawValue
                existing.isCorrect = item.isCorrect
                existing.timeSpentMs = item.timeSpentMs
                existing.selectedTrap = item.selectedTrap
                existing.selectedOptionIndex = item.selectedOptionIndex
                existing.sourceRaw = item.source.rawValue
                existing.timestampMs = item.timestamp
            } else {
                let record = QuestionAttempt(
                    id: resolvedId,
                    questionId: item.questionId,
                    topic: item.topic,
                    isCorrect: item.isCorrect,
                    timeSpentMs: item.timeSpentMs,
                    selectedTrap: item.selectedTrap,
                    selectedOptionIndex: item.selectedOptionIndex,
                    source: item.source,
                    timestampMs: item.timestamp
                )
                context.insert(record)
                attemptById[resolvedId] = record
            }
            telemetryImported += 1
        }

        let existingSessions = (try? context.fetch(FetchDescriptor<MockSessionRecord>())) ?? []
        var sessionById = Dictionary(existingSessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var mockSessionsImported = 0

        for session in payload.mockSessions {
            if let existing = sessionById[session.id] {
                existing.startedAtMs = session.startedAt
                existing.completedAtMs = session.completedAt
                existing.passageIds = session.passageIds
                existing.answers = session.answers
                existing.flaggedQuestionIds = session.flaggedQuestionIds
                existing.timeSpentByQuestionMs = session.timeSpentByQuestionMs
                existing.totalElapsedMs = session.totalElapsedMs
                existing.score = session.score
                existing.totalQuestions = session.totalQuestions
                existing.status = session.status
            } else {
                let record = MockSessionRecord(
                    id: session.id,
                    startedAtMs: session.startedAt,
                    completedAtMs: session.completedAt,
                    passageIds: session.passageIds,
                    answers: session.answers,
                    flaggedQuestionIds: session.flaggedQuestionIds,
                    timeSpentByQuestionMs: session.timeSpentByQuestionMs,
                    totalElapsedMs: session.totalElapsedMs,
                    score: session.score,
                    totalQuestions: session.totalQuestions,
                    status: session.status
                )
                context.insert(record)
                sessionById[session.id] = record
            }
            mockSessionsImported += 1
        }

        let existingOutlines = (try? context.fetch(FetchDescriptor<SavedOutline>())) ?? []
        var outlineById = Dictionary(existingOutlines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var outlinesImported = 0

        for outline in payload.sectionBOutlines {
            let p1 = !outline.point1.isEmpty ? outline.point1 : (outline.propositionPoints.first ?? "")
            let p2 = !outline.point2.isEmpty
                ? outline.point2
                : (outline.propositionPoints.count > 1 ? outline.propositionPoints[1] : "")
            let reb = !outline.rebuttal.isEmpty ? outline.rebuttal : outline.rebuttalAndSynthesis

            if let existing = outlineById[outline.id] {
                existing.promptId = outline.promptId
                existing.promptText = outline.promptText
                existing.thesis = outline.thesis
                existing.point1 = p1
                existing.point2 = p2
                existing.counterargument = outline.counterargument
                existing.rebuttal = reb
                existing.conclusionHook = outline.conclusionHook
                existing.durationSeconds = outline.durationSeconds
                existing.createdAtMs = outline.createdAt
                existing.updatedAtMs = outline.updatedAt
            } else {
                let record = SavedOutline(
                    id: outline.id,
                    promptId: outline.promptId,
                    promptText: outline.promptText,
                    thesis: outline.thesis,
                    point1: p1,
                    point2: p2,
                    counterargument: outline.counterargument,
                    rebuttal: reb,
                    conclusionHook: outline.conclusionHook,
                    durationSeconds: outline.durationSeconds,
                    createdAtMs: outline.createdAt,
                    updatedAtMs: outline.updatedAt
                )
                context.insert(record)
                outlineById[outline.id] = record
            }
            outlinesImported += 1
        }

        let existingCompleted = (try? context.fetch(FetchDescriptor<CompletedCardRecord>())) ?? []
        var existingCardIds = Set(existingCompleted.map(\.cardId))
        for cardId in payload.completedCardIds where !existingCardIds.contains(cardId) {
            context.insert(CompletedCardRecord(cardId: cardId))
            existingCardIds.insert(cardId)
        }

        try context.save()
        return BackupImportSummary(
            telemetryImported: telemetryImported,
            mockSessionsImported: mockSessionsImported,
            outlinesImported: outlinesImported
        )
    }

    public static func resetAllStudyHistory(in context: ModelContext) throws {
        let attempts = (try? context.fetch(FetchDescriptor<QuestionAttempt>())) ?? []
        for item in attempts { context.delete(item) }

        let sessions = (try? context.fetch(FetchDescriptor<MockSessionRecord>())) ?? []
        for item in sessions { context.delete(item) }

        let outlines = (try? context.fetch(FetchDescriptor<SavedOutline>())) ?? []
        for item in outlines { context.delete(item) }

        let completed = (try? context.fetch(FetchDescriptor<CompletedCardRecord>())) ?? []
        for item in completed { context.delete(item) }

        try context.save()
    }
}
