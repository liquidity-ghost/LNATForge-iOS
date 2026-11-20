import SwiftUI

public struct MockReviewView: View {
    @Environment(\.lnatPalette) private var palette

    public let session: MockExamSessionDTO
    public let passages: [MockPassage]
    public let autoSubmitted: Bool
    public let emitBackHaptic: Bool
    public let onBackToLaunch: () -> Void

    @State private var expandedQuestionId: String?
    @State private var backHapticTrigger = 0

    private let reviewItems: [ExamQuestionItem]
    private let firstMissedId: String?

    public init(
        session: MockExamSessionDTO,
        passages: [MockPassage],
        autoSubmitted: Bool = false,
        emitBackHaptic: Bool = true,
        onBackToLaunch: @escaping () -> Void
    ) {
        self.session = session
        self.passages = passages
        self.autoSubmitted = autoSubmitted
        self.emitBackHaptic = emitBackHaptic
        self.onBackToLaunch = onBackToLaunch

        let passageMap = Dictionary(uniqueKeysWithValues: passages.map { ($0.id, $0) })
        var items: [ExamQuestionItem] = []
        for pid in session.passageIds {
            guard let passage = passageMap[pid] else { continue }
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
        self.reviewItems = items
        let firstMissed = items.first { item in
            session.answers[item.question.id] != item.question.correctIndex
        }
        self.firstMissedId = firstMissed?.question.id ?? items.first?.question.id
        self._expandedQuestionId = State(initialValue: self.firstMissedId)
    }

    private var totalQuestions: Int {
        max(1, reviewItems.isEmpty ? session.totalQuestions : reviewItems.count)
    }

    private var score: Int {
        session.score ?? reviewItems.filter { session.answers[$0.question.id] == $0.question.correctIndex }.count
    }

    private var accuracyPercent: Int {
        Int(((Double(score) / Double(totalQuestions)) * 100.0).rounded(.toNearestOrAwayFromZero))
    }

    private var answeredCount: Int {
        reviewItems.filter { session.answers[$0.question.id] != nil }.count
    }

    private var avgSecondsPerQuestion: Int {
        let timedValues = Array(session.timeSpentByQuestionMs.values)
        if !timedValues.isEmpty && answeredCount > 0 {
            let totalTrackedMs = timedValues.reduce(0, +)
            return max(1, Int((Double(totalTrackedMs) / 1000.0 / Double(max(1, totalQuestions))).rounded(.toNearestOrAwayFromZero)))
        }
        return max(0, Int((Double(session.totalElapsedMs) / 1000.0 / Double(totalQuestions)).rounded(.toNearestOrAwayFromZero)))
    }

    private var trapBreakdown: (entries: [TrapCount], totalIncorrectOrBlank: Int) {
        var counts: [String: Int] = [:]
        var totalMissed = 0

        for item in reviewItems {
            if let selected = session.answers[item.question.id] {
                if selected != item.question.correctIndex {
                    totalMissed += 1
                    let label: String
                    if selected >= 0 && selected < item.question.trapLabels.count,
                       let trap = item.question.trapLabels[selected], !trap.isEmpty {
                        label = trap
                    } else {
                        label = "Wrong Answer"
                    }
                    counts[label, default: 0] += 1
                }
            } else {
                totalMissed += 1
                counts["Unanswered", default: 0] += 1
            }
        }

        let entries = counts
            .map { TrapCount(trap: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.trap < $1.trap
            }
        return (entries, totalMissed)
    }

    private var flaggedSet: Set<String> {
        Set(session.flaggedQuestionIds)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    if emitBackHaptic {
                        backHapticTrigger += 1
                    }
                    onBackToLaunch()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Practice Papers")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(palette.accentPrimary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                if autoSubmitted {
                    Text("Time Expired")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.statusTrapText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(palette.statusTrapBg)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(palette.statusTrapBorder, lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(palette.bgSurface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.borderSubtle).frame(height: 1)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    kpiGrid
                    commonMistakesCard
                    answerReviewSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bgApp)
        .sensoryFeedback(.impact(weight: .light), trigger: backHapticTrigger)
    }

    private var kpiGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: cols, spacing: 10) {
            kpiCard(title: "SCORE") {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(palette.textPrimary)
                    Text("/ \(totalQuestions)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                }
            }

            kpiCard(title: "ACCURACY") {
                Text("\(accuracyPercent)%")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(accuracyPercent >= 75 ? palette.statusCorrectText : palette.accentSecondaryText)
            }

            kpiCard(title: "AVG. TIME", icon: "clock", iconColor: palette.accentBlueText) {
                Text("\(avgSecondsPerQuestion)s")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
            }

            kpiCard(title: "ANSWERED", icon: "scope", iconColor: palette.statusCorrectText) {
                Text("\(answeredCount)/\(totalQuestions)")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
            }
        }
    }

    private func kpiCard<Content: View>(
        title: String,
        icon: String? = nil,
        iconColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(iconColor ?? palette.textSecondary)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(palette.textSecondary)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
    }

    private var commonMistakesCard: some View {
        let breakdown = trapBreakdown
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.statusTrapText)
                    Text("Common Mistakes")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                }
                Spacer()
                Text("\(breakdown.totalIncorrectOrBlank) missed")
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textSecondary)
            }

            if breakdown.entries.isEmpty {
                Text("Every question answered correctly.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(palette.statusCorrectText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.statusCorrectBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.statusCorrectBorder, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 10) {
                    ForEach(breakdown.entries) { entry in
                        let ratio = Double(entry.count) / Double(max(1, breakdown.totalIncorrectOrBlank))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                Text(entry.trap)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(palette.textPrimary)
                                Spacer()
                                Text("\(entry.count)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(palette.statusTrapText)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(palette.bgSoftAccent)
                                    Capsule()
                                        .fill(palette.statusTrapSolid)
                                        .frame(width: max(12, geo.size.width * max(0.08, ratio)))
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
    }

    private var answerReviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ANSWER REVIEW")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 2)

            ForEach(reviewItems) { item in
                reviewAccordionCard(item)
            }
        }
    }

    private func reviewAccordionCard(_ item: ExamQuestionItem) -> some View {
        let q = item.question
        let selected = session.answers[q.id]
        let isAnswered = selected != nil
        let isCorrect = isAnswered && selected == q.correctIndex
        let isFlagged = flaggedSet.contains(q.id)
        let isExpanded = expandedQuestionId == q.id
        let qTimeSec = Int((Double(session.timeSpentByQuestionMs[q.id] ?? 0) / 1000.0).rounded(.toNearestOrAwayFromZero))
        let correctLetter = ExamBuilder.optionLetters[safe: q.correctIndex] ?? "?"

        let statusSummary: String = {
            var base: String
            if isCorrect {
                base = "Correct (\(correctLetter))"
            } else if let selected {
                let chosenLetter = ExamBuilder.optionLetters[safe: selected] ?? "?"
                base = "Selected \(chosenLetter) · Correct \(correctLetter)"
            } else {
                base = "Unanswered · Correct \(correctLetter)"
            }
            if qTimeSec > 0 {
                base += " · \(qTimeSec)s"
            }
            return base
        }()

        return VStack(spacing: 0) {
            Button {
                Haptics.impact(.light)
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedQuestionId = isExpanded ? nil : q.id
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isCorrect ? palette.statusCorrectText : palette.statusTrapText)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Question \(item.questionNumberInExam)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(palette.textPrimary)
                            Text(q.topic.rawValue)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(palette.accentSecondaryText)
                            if isFlagged {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(palette.accentSecondaryText)
                            }
                        }

                        Text(statusSummary)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Rectangle().fill(palette.borderSubtle).frame(height: 1)

                    Text(item.passage.title)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(palette.textSecondary)

                    FormattedBlockView(
                        text: q.stem,
                        font: .system(size: 13.5, weight: .semibold),
                        lineSpacing: 3
                    )

                    VStack(spacing: 6) {
                        ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                            let isOptCorrect = idx == q.correctIndex
                            let isOptSelected = selected == idx
                            let letter = ExamBuilder.optionLetters[safe: idx] ?? "?"

                            let bg: Color = isOptCorrect ? palette.statusCorrectBg : (isOptSelected ? palette.statusTrapBg : palette.bgMuted)
                            let border: Color = isOptCorrect ? palette.statusCorrectBorder : (isOptSelected ? palette.statusTrapBorder : palette.borderSubtle.opacity(0.7))
                            let fg: Color = isOptCorrect ? palette.statusCorrectText : (isOptSelected ? palette.statusTrapText : palette.textSecondary)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(letter).")
                                        .font(.system(size: 12.5, weight: .bold))
                                    Text(opt)
                                        .font(.system(size: 12.5))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                if isOptCorrect || isOptSelected {
                                    let trap = (idx < q.trapLabels.count ? q.trapLabels[idx] : nil) ?? "Incorrect"
                                    Text(isOptCorrect ? "Correct Answer" : "Your Choice — \(trap)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .opacity(0.9)
                                }
                            }
                            .foregroundStyle(fg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(bg)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(border, lineWidth: 1)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXPLANATION")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(palette.statusCorrectText)
                        Text(q.explanation)
                            .font(.system(size: 12.5))
                            .lineSpacing(3.5)
                            .foregroundStyle(palette.textPrimary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.bgMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(palette.borderSubtle, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

public struct PastAttemptReviewView: View {
    @Environment(\.dismiss) private var dismiss

    public let session: MockExamSessionDTO
    public let passages: [MockPassage]

    public init(session: MockExamSessionDTO, passages: [MockPassage]) {
        self.session = session
        self.passages = passages
    }

    public var body: some View {
        MockReviewView(
            session: session,
            passages: passages,
            autoSubmitted: false,
            emitBackHaptic: false,
            onBackToLaunch: { dismiss() }
        )
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractivePopGesture()
    }
}
