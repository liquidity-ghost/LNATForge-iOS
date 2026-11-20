import Foundation

public enum MasteryStatus: String, Codable, Hashable, Sendable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case nearMastery = "Near Mastery"
    case mastered = "Mastered"
}

public struct TrapCount: Codable, Hashable, Identifiable, Sendable {
    public let trap: String
    public let count: Int

    public var id: String { trap }

    public init(trap: String, count: Int) {
        self.trap = trap
        self.count = count
    }
}

public struct TopicMastery: Hashable, Identifiable, Sendable {
    public let topic: LnatTopic
    public let attempted: Int
    public let feedAttempted: Int
    public let mockAttempted: Int
    public let correct: Int
    public let rawAccuracy: Double
    public let decayedAccuracy: Double
    public let masteryPercent: Int
    public let isMastered: Bool
    public let status: MasteryStatus
    public let avgTimeMs: Int
    public let avgTimeSeconds: Int
    public let isSlowPace: Bool
    public let frequentTraps: [TrapCount]
    public let lastAttemptedAt: Int64?

    public var id: String { topic.rawValue }
}

public struct WeakTopicSummary: Hashable, Identifiable, Sendable {
    public let rank: Int
    public let topic: LnatTopic
    public let shortLabel: String
    public let attempted: Int
    public let correct: Int
    public let masteryPercent: Int
    public let status: MasteryStatus
    public let avgTimeSeconds: Int
    public let isSlowPace: Bool
    public let topTrap: TrapCount?
    public let reasonLabel: String

    public var id: String { topic.rawValue }
}

public struct OverallStats: Hashable, Sendable {
    public let totalAttempted: Int
    public let feedAttempted: Int
    public let mockAttempted: Int
    public let totalCorrect: Int
    public let accuracyPercent: Int
    public let masteredCount: Int
    public let avgTimeSeconds: Int
    public let isOverallSlowPace: Bool
    public let slowTopicsCount: Int
    public let topTrap: TrapCount?
    public let weakestTopics: [WeakTopicSummary]
}

public enum DiagnosticsEngine {
    public static let masteryMinAttempts = 5
    public static let masteryThreshold = 0.8
    public static let mockMissDecayPerMiss = 0.04
    public static let maxDecayPenalty = 0.24
    public static let targetPaceSeconds = 135
    public static let targetPaceMs = targetPaceSeconds * 1000

    public static func filterGradedTelemetry(
        _ telemetry: [QuestionTelemetryDTO],
        primerCardIds: Set<String>,
        validGradedQuestionIds: Set<String>
    ) -> [QuestionTelemetryDTO] {
        telemetry.filter { item in
            (item.source == .feed || item.source == .mock)
                && !primerCardIds.contains(item.questionId)
                && !item.questionId.hasPrefix("primer-")
                && validGradedQuestionIds.contains(item.questionId)
        }
    }

    public static func computeTopicMastery(
        telemetry: [QuestionTelemetryDTO],
        topic: LnatTopic,
        primerCardIds: Set<String>,
        validGradedQuestionIds: Set<String>
    ) -> TopicMastery {
        let records = filterGradedTelemetry(
            telemetry,
            primerCardIds: primerCardIds,
            validGradedQuestionIds: validGradedQuestionIds
        )
        .filter { $0.topic == topic }
        .sorted { $0.timestamp < $1.timestamp }

        let attempted = records.count
        if attempted == 0 {
            return TopicMastery(
                topic: topic,
                attempted: 0,
                feedAttempted: 0,
                mockAttempted: 0,
                correct: 0,
                rawAccuracy: 0,
                decayedAccuracy: 0,
                masteryPercent: 0,
                isMastered: false,
                status: .notStarted,
                avgTimeMs: 0,
                avgTimeSeconds: 0,
                isSlowPace: false,
                frequentTraps: [],
                lastAttemptedAt: nil
            )
        }

        let feedAttempted = records.filter { $0.source == .feed }.count
        let mockAttempted = records.filter { $0.source == .mock }.count
        let correct = records.filter(\.isCorrect).count
        let rawAccuracy = Double(correct) / Double(attempted)

        // Apply mild decay (-4% per incorrect mock question occurring after the 5th attempt)
        var decayPenalty = 0.0
        for (index, record) in records.enumerated() {
            if index >= masteryMinAttempts && record.source == .mock && !record.isCorrect {
                decayPenalty += mockMissDecayPerMiss
            }
        }

        let decayedAccuracy = max(0.0, rawAccuracy - min(maxDecayPenalty, decayPenalty))
        let masteryPercent = Int((decayedAccuracy * 100.0).rounded(.toNearestOrAwayFromZero))
        let isMastered = attempted >= masteryMinAttempts && decayedAccuracy >= masteryThreshold

        let status: MasteryStatus
        if isMastered {
            status = .mastered
        } else if attempted >= 3 && decayedAccuracy >= 0.7 {
            status = .nearMastery
        } else {
            status = .inProgress
        }

        let totalTime = records.reduce(0) { $0 + max(0, $1.timeSpentMs) }
        let avgTimeMs = Int((Double(totalTime) / Double(attempted)).rounded(.toNearestOrAwayFromZero))
        let avgTimeSeconds = Int((Double(avgTimeMs) / 1000.0).rounded(.toNearestOrAwayFromZero))
        let isSlowPace = attempted > 0 && avgTimeMs > targetPaceMs

        var trapMap: [String: Int] = [:]
        for record in records {
            if !record.isCorrect, let trap = record.selectedTrap, !trap.isEmpty {
                trapMap[trap, default: 0] += 1
            }
        }

        let frequentTraps = trapMap
            .map { TrapCount(trap: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.trap < $1.trap
            }

        let lastAttemptedAt = records.last?.timestamp

        return TopicMastery(
            topic: topic,
            attempted: attempted,
            feedAttempted: feedAttempted,
            mockAttempted: mockAttempted,
            correct: correct,
            rawAccuracy: rawAccuracy,
            decayedAccuracy: decayedAccuracy,
            masteryPercent: masteryPercent,
            isMastered: isMastered,
            status: status,
            avgTimeMs: avgTimeMs,
            avgTimeSeconds: avgTimeSeconds,
            isSlowPace: isSlowPace,
            frequentTraps: frequentTraps,
            lastAttemptedAt: lastAttemptedAt
        )
    }

    public static func computeAllTopicMastery(
        telemetry: [QuestionTelemetryDTO],
        primerCardIds: Set<String>,
        validGradedQuestionIds: Set<String>
    ) -> [TopicMastery] {
        LnatTopic.allCases.map { topic in
            computeTopicMastery(
                telemetry: telemetry,
                topic: topic,
                primerCardIds: primerCardIds,
                validGradedQuestionIds: validGradedQuestionIds
            )
        }
    }

    private static func weaknessTier(for item: TopicMastery) -> Int {
        if item.attempted > 0 && !item.isMastered { return 0 }
        if item.attempted == 0 { return 1 }
        return 2
    }

    private static func buildWeakReasonLabel(for item: TopicMastery) -> String {
        if item.attempted == 0 {
            return "Not started · \(masteryMinAttempts) questions needed"
        }
        if item.isSlowPace {
            return "\(item.masteryPercent)% accuracy · \(item.avgTimeSeconds)s avg. time"
        }
        if item.attempted < masteryMinAttempts {
            return "\(item.masteryPercent)% accuracy · \(item.attempted) of \(masteryMinAttempts) questions"
        }
        if !item.isMastered {
            return "\(item.masteryPercent)% accuracy · Aim for 80%+"
        }
        return "\(item.masteryPercent)% accuracy · \(item.avgTimeSeconds)s avg. time"
    }

    public static func computeWeakestTopics(
        telemetry: [QuestionTelemetryDTO],
        primerCardIds: Set<String>,
        validGradedQuestionIds: Set<String>,
        limit: Int = 2
    ) -> [WeakTopicSummary] {
        let masteryList = computeAllTopicMastery(
            telemetry: telemetry,
            primerCardIds: primerCardIds,
            validGradedQuestionIds: validGradedQuestionIds
        )

        let sorted = masteryList.sorted { a, b in
            let tierA = weaknessTier(for: a)
            let tierB = weaknessTier(for: b)
            if tierA != tierB { return tierA < tierB }

            if tierA == 0 {
                if a.decayedAccuracy != b.decayedAccuracy {
                    return a.decayedAccuracy < b.decayedAccuracy
                }
                if a.isSlowPace != b.isSlowPace {
                    return a.isSlowPace && !b.isSlowPace
                }
                if a.avgTimeMs != b.avgTimeMs {
                    return a.avgTimeMs > b.avgTimeMs
                }
                let aTrapCount = a.frequentTraps.reduce(0) { $0 + $1.count }
                let bTrapCount = b.frequentTraps.reduce(0) { $0 + $1.count }
                if aTrapCount != bTrapCount {
                    return aTrapCount > bTrapCount
                }
            } else if tierA == 2 {
                if a.decayedAccuracy != b.decayedAccuracy {
                    return a.decayedAccuracy < b.decayedAccuracy
                }
                if a.avgTimeMs != b.avgTimeMs {
                    return a.avgTimeMs > b.avgTimeMs
                }
            }

            return a.topic.orderIndex < b.topic.orderIndex
        }

        return sorted.prefix(limit).enumerated().map { index, item in
            WeakTopicSummary(
                rank: index + 1,
                topic: item.topic,
                shortLabel: item.topic.shortLabel,
                attempted: item.attempted,
                correct: item.correct,
                masteryPercent: item.masteryPercent,
                status: item.status,
                avgTimeSeconds: item.avgTimeSeconds,
                isSlowPace: item.isSlowPace,
                topTrap: item.frequentTraps.first,
                reasonLabel: buildWeakReasonLabel(for: item)
            )
        }
    }

    public static func computeOverallStats(
        telemetry: [QuestionTelemetryDTO],
        primerCardIds: Set<String>,
        validGradedQuestionIds: Set<String>
    ) -> OverallStats {
        let gradedTelemetry = filterGradedTelemetry(
            telemetry,
            primerCardIds: primerCardIds,
            validGradedQuestionIds: validGradedQuestionIds
        )

        let totalAttempted = gradedTelemetry.count
        let feedAttempted = gradedTelemetry.filter { $0.source == .feed }.count
        let mockAttempted = gradedTelemetry.filter { $0.source == .mock }.count
        let totalCorrect = gradedTelemetry.filter(\.isCorrect).count
        let accuracyPercent = totalAttempted == 0
            ? 0
            : Int(((Double(totalCorrect) / Double(totalAttempted)) * 100.0).rounded(.toNearestOrAwayFromZero))

        let masteryList = computeAllTopicMastery(
            telemetry: gradedTelemetry,
            primerCardIds: primerCardIds,
            validGradedQuestionIds: validGradedQuestionIds
        )
        let masteredCount = masteryList.filter(\.isMastered).count
        let slowTopicsCount = masteryList.filter(\.isSlowPace).count

        let totalTimeMs = gradedTelemetry.reduce(0) { $0 + max(0, $1.timeSpentMs) }
        let avgTimeMs = totalAttempted == 0
            ? 0
            : Int((Double(totalTimeMs) / Double(totalAttempted)).rounded(.toNearestOrAwayFromZero))
        let avgTimeSeconds = Int((Double(avgTimeMs) / 1000.0).rounded(.toNearestOrAwayFromZero))
        let isOverallSlowPace = totalAttempted > 0 && avgTimeMs > targetPaceMs

        var trapMap: [String: Int] = [:]
        for record in gradedTelemetry {
            if !record.isCorrect, let trap = record.selectedTrap, !trap.isEmpty {
                trapMap[trap, default: 0] += 1
            }
        }
        let sortedTraps = trapMap
            .map { TrapCount(trap: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.trap < $1.trap
            }

        let weakestTopics = computeWeakestTopics(
            telemetry: gradedTelemetry,
            primerCardIds: primerCardIds,
            validGradedQuestionIds: validGradedQuestionIds,
            limit: 2
        )

        return OverallStats(
            totalAttempted: totalAttempted,
            feedAttempted: feedAttempted,
            mockAttempted: mockAttempted,
            totalCorrect: totalCorrect,
            accuracyPercent: accuracyPercent,
            masteredCount: masteredCount,
            avgTimeSeconds: avgTimeSeconds,
            isOverallSlowPace: isOverallSlowPace,
            slowTopicsCount: slowTopicsCount,
            topTrap: sortedTraps.first,
            weakestTopics: weakestTopics
        )
    }
}
