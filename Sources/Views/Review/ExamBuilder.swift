import Foundation

public enum MockExamMode: String, Sendable {
    case paper1 = "paper_1_95m"
    case paper2 = "paper_2_95m"
    case quick18m = "quick_18m"
}

public struct ExamQuestionItem: Identifiable, Hashable, Sendable {
    public let globalIndex: Int
    public let questionNumberInExam: Int
    public let question: MockQuestion
    public let passage: MockPassage

    public var id: String { question.id }
}

public struct BuiltMockExam: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let mode: MockExamMode
    public let label: String
    public let passageIds: [String]
    public let items: [ExamQuestionItem]
    public let durationSeconds: Int
}

public enum ExamBuilder {
    public static let optionLetters = ["A", "B", "C", "D", "E"]

    public static func build(passages: [MockPassage], mode: MockExamMode) -> BuiltMockExam {
        var items: [ExamQuestionItem] = []
        var passageIds: [String] = []

        if mode == .quick18m {
            let uniquePool = passages.filter { $0.duplicateOf == nil }
            let shuffled = uniquePool.shuffled()
            var picked: [MockPassage] = []
            var seenTitles = Set<String>()
            for candidate in shuffled {
                if seenTitles.contains(candidate.title) { continue }
                seenTitles.insert(candidate.title)
                picked.append(candidate)
                if picked.count == 2 { break }
            }
            appendPassageQuestions(picked, passageIds: &passageIds, items: &items)
            return BuiltMockExam(
                mode: mode,
                label: "Quick Session",
                passageIds: passageIds,
                items: items,
                durationSeconds: 18 * 60
            )
        }

        let targetPaper: MockPaperId = mode == .paper2 ? .paper2 : .paper1
        let orderedPassages = passages
            .filter { $0.paperId == targetPaper }
            .sorted { $0.passageNumber < $1.passageNumber }

        appendPassageQuestions(orderedPassages, passageIds: &passageIds, items: &items)

        return BuiltMockExam(
            mode: mode,
            label: mode == .paper2 ? "Official Test Version 2" : "Official Test Version 1",
            passageIds: passageIds,
            items: items,
            durationSeconds: 95 * 60
        )
    }

    private static func appendPassageQuestions(
        _ selectedPassages: [MockPassage],
        passageIds: inout [String],
        items: inout [ExamQuestionItem]
    ) {
        for passage in selectedPassages {
            passageIds.append(passage.id)
            for question in passage.questions {
                items.append(
                    ExamQuestionItem(
                        globalIndex: items.count,
                        questionNumberInExam: items.count + 1,
                        question: question,
                        passage: passage
                    )
                )
            }
        }
    }

    public static func formatCountdown(_ totalSeconds: Int) -> String {
        let safe = max(0, totalSeconds)
        let mins = safe / 60
        let secs = safe % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
