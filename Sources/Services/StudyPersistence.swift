import Foundation
import SwiftData

@MainActor
public enum StudyPersistence {
    public static func markCardCompleted(_ cardId: String, in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<CompletedCardRecord>())) ?? []
        guard !existing.contains(where: { $0.cardId == cardId }) else { return }
        context.insert(CompletedCardRecord(cardId: cardId))
        try? context.save()
    }

    public static func unmarkCardsCompleted(_ cardIds: Set<String>, in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<CompletedCardRecord>())) ?? []
        for record in existing where cardIds.contains(record.cardId) {
            context.delete(record)
        }
        try? context.save()
    }

    public static func recordFeedAnswer(
        cardId: String,
        questionId: String,
        topic: LnatTopic,
        isCorrect: Bool,
        timeSpentMs: Int,
        selectedTrap: String?,
        selectedOptionIndex: Int,
        in context: ModelContext
    ) {
        let attempt = QuestionAttempt(
            questionId: questionId,
            topic: topic,
            isCorrect: isCorrect,
            timeSpentMs: timeSpentMs,
            selectedTrap: selectedTrap,
            selectedOptionIndex: selectedOptionIndex,
            source: .feed
        )
        context.insert(attempt)
        markCardCompleted(cardId, in: context)
        try? context.save()
    }
}
