import Combine
import SwiftData
import SwiftUI

public struct MockExamRunnerView: View {
    @Environment(\.lnatPalette) private var palette
    @Environment(\.modelContext) private var modelContext

    public enum LayoutMode: String, CaseIterable {
        case passage = "Passage"
        case split = "Split"
        case question = "Question"
    }

    public let builtExam: BuiltMockExam
    public let onComplete: (MockExamSessionDTO, Bool) -> Void
    public let onExit: () -> Void

    @State private var activeIndex = 0
    @State private var answers: [String: Int] = [:]
    @State private var flaggedIds: Set<String> = []
    @State private var timeSpentByQuestionMs: [String: Int] = [:]
    @State private var secondsLeft: Int
    @State private var startedAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    @State private var questionEnteredAt = Date()
    @State private var hasSubmitted = false

    @State private var layoutMode: LayoutMode = .split
    @State private var fontSizeIdx = 2
    @State private var isGridOpen = false
    @State private var showExitConfirmation = false
    @State private var optionSelectTrigger = 0

    private let fontSizeSteps: [CGFloat] = [14, 15, 16, 17, 18.5]
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(
        builtExam: BuiltMockExam,
        onComplete: @escaping (MockExamSessionDTO, Bool) -> Void,
        onExit: @escaping () -> Void
    ) {
        self.builtExam = builtExam
        self.onComplete = onComplete
        self.onExit = onExit
        self._secondsLeft = State(initialValue: builtExam.durationSeconds)
    }

    private var activeItem: ExamQuestionItem? {
        guard activeIndex >= 0 && activeIndex < builtExam.items.count else { return nil }
        return builtExam.items[activeIndex]
    }

    private var answeredCount: Int {
        builtExam.items.filter { answers[$0.question.id] != nil }.count
    }

    private var showPassage: Bool {
        layoutMode == .split || layoutMode == .passage
    }

    private var showQuestion: Bool {
        layoutMode == .split || layoutMode == .question
    }

    private var isLowTime: Bool {
        secondsLeft <= 120
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let item = activeItem {
                examHeader(item: item)
                toolbarBar

                GeometryReader { geo in
                    VStack(spacing: 0) {
                        if showPassage {
                            passageSection(item.passage)
                                .frame(height: layoutMode == .split ? geo.size.height * 0.45 : geo.size.height)
                        }

                        if showPassage && showQuestion {
                            Rectangle().fill(palette.borderSubtle).frame(height: 1)
                        }

                        if showQuestion {
                            questionSection(item: item)
                                .frame(maxHeight: .infinity)
                        }
                    }
                }

                bottomNavigationBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bgApp)
        .onReceive(ticker) { _ in
            guard !hasSubmitted else { return }
            if secondsLeft <= 1 {
                secondsLeft = 0
                submitExam(autoSubmitted: true)
            } else {
                secondsLeft -= 1
            }
        }
        .sheet(isPresented: $isGridOpen) {
            QuestionGridSheet(
                items: builtExam.items,
                activeIndex: activeIndex,
                answers: answers,
                flaggedIds: flaggedIds,
                onSelectQuestion: { idx in selectIndex(idx) },
                onSubmitExam: { submitExam(autoSubmitted: false) }
            )
            .environment(\.lnatPalette, palette)
        }
        .alert("Exit Test?", isPresented: $showExitConfirmation) {
            Button("Keep Working", role: .cancel) {}
            Button("Exit Without Saving", role: .destructive) {
                onExit()
            }
        } message: {
            Text("Your progress in this timed session will not be saved.")
        }
        .sensoryFeedback(.selection, trigger: layoutMode)
        .sensoryFeedback(.selection, trigger: fontSizeIdx)
        .sensoryFeedback(.selection, trigger: optionSelectTrigger)
    }

    // MARK: - Top Exam Bar

    private func examHeader(item: ExamQuestionItem) -> some View {
        HStack(spacing: 8) {
            Button {
                Haptics.impact(.light)
                if answeredCount > 0 {
                    showExitConfirmation = true
                } else {
                    onExit()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("Exit")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .background(palette.bgMuted)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(palette.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("Q\(item.questionNumberInExam) of \(builtExam.items.count)")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Text(builtExam.label)
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .semibold))
                Text(ExamBuilder.formatCountdown(secondsLeft))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(isLowTime ? palette.statusTrapText : palette.accentPrimary)
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(isLowTime ? palette.statusTrapBg : palette.bgMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isLowTime ? palette.statusTrapBorder : palette.borderSubtle, lineWidth: 1)
            )

            Button {
                Haptics.impact(.medium)
                submitExam(autoSubmitted: false)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 11))
                    Text("Submit")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(palette.statusCorrectSolidFg)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(palette.statusCorrectSolid)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(palette.bgSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.borderSubtle).frame(height: 1)
        }
    }

    private var toolbarBar: some View {
        HStack {
            HStack(spacing: 2) {
                ForEach(LayoutMode.allCases, id: \.self) { mode in
                    let isSelected = layoutMode == mode
                    Button {
                        layoutMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? palette.accentPrimaryFg : palette.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? palette.accentPrimary : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(palette.bgMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(palette.borderSubtle, lineWidth: 1)
            )

            Spacer()

            HStack(spacing: 4) {
                Button {
                    fontSizeIdx = max(0, fontSizeIdx - 1)
                } label: {
                    Text("A-")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(palette.bgMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(palette.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(fontSizeIdx == 0 || !showPassage)
                .opacity((fontSizeIdx == 0 || !showPassage) ? 0.35 : 1)

                Button {
                    fontSizeIdx = min(fontSizeSteps.count - 1, fontSizeIdx + 1)
                } label: {
                    Text("A+")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(palette.bgMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(palette.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(fontSizeIdx == fontSizeSteps.count - 1 || !showPassage)
                .opacity((fontSizeIdx == fontSizeSteps.count - 1 || !showPassage) ? 0.35 : 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(palette.bgSurface.opacity(0.95))
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.borderSubtle).frame(height: 1)
        }
    }

    // MARK: - Passage & Question Panes

    private func passageSection(_ passage: MockPassage) -> some View {
        let fontSize = fontSizeSteps[fontSizeIdx]
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Color.clear.frame(height: 0).id("passageTop")

                    VStack(alignment: .leading, spacing: 3) {
                        Text(passage.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(palette.textPrimary)
                        Text(passage.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.textSecondary)
                    }

                    ForEach(Array(passage.paragraphs.enumerated()), id: \.offset) { _, para in
                        FormattedBlockView(
                            text: para,
                            font: .system(size: fontSize, design: .serif),
                            lineSpacing: fontSize * 0.45
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.bgApp)
            .onChange(of: passage.id) { _, _ in
                proxy.scrollTo("passageTop", anchor: .top)
            }
        }
    }

    private func questionSection(item: ExamQuestionItem) -> some View {
        let q = item.question
        let selectedOption = answers[q.id]
        let isFlagged = flaggedIds.contains(q.id)

        return VStack(spacing: 0) {
            HStack {
                Text(q.topic.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.accentSecondaryText)

                Spacer()

                Button {
                    Haptics.impact(.light)
                    if isFlagged {
                        flaggedIds.remove(q.id)
                    } else {
                        flaggedIds.insert(q.id)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isFlagged ? "flag.fill" : "flag")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isFlagged ? "Flagged" : "Flag")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(isFlagged ? palette.accentSecondaryText : palette.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(isFlagged ? palette.bgSoftAccent : palette.bgMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isFlagged ? palette.accentSecondary : palette.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.borderSubtle).frame(height: 1)
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        Color.clear.frame(height: 0).id("questionTop")

                        FormattedBlockView(
                            text: q.stem,
                            font: .system(size: 14.5, weight: .semibold),
                            lineSpacing: 3
                        )

                        VStack(spacing: 8) {
                            ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                                let isSelected = selectedOption == idx
                                let letter = idx < ExamBuilder.optionLetters.count ? ExamBuilder.optionLetters[idx] : "?"

                                Button {
                                    answers[q.id] = idx
                                    optionSelectTrigger += 1
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(letter)
                                            .font(.system(size: 10.5, weight: .bold))
                                            .foregroundStyle(isSelected ? palette.accentPrimaryFg : palette.accentPrimary)
                                            .frame(width: 22, height: 22)
                                            .background(isSelected ? palette.accentPrimary : palette.bgSurface)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(isSelected ? palette.accentPrimary : palette.borderSubtle, lineWidth: 1)
                                            )
                                            .padding(.top, 1)

                                        Text(opt)
                                            .font(.system(size: 13))
                                            .lineSpacing(2.5)
                                            .foregroundStyle(palette.textPrimary)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(minHeight: 44)
                                    .background(isSelected ? palette.bgSoftAccent : palette.bgMuted)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isSelected ? palette.accentPrimary : palette.borderSubtle, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: q.id) { _, _ in
                    proxy.scrollTo("questionTop", anchor: .top)
                }
            }
        }
        .background(palette.bgSurface)
    }

    // MARK: - Bottom Exam Navigation

    private var bottomNavigationBar: some View {
        HStack {
            Button {
                Haptics.impact(.light)
                selectIndex(activeIndex - 1)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Previous")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(palette.bgMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.borderSubtle, lineWidth: 1)
                )
                .opacity(activeIndex == 0 ? 0.35 : 1)
            }
            .buttonStyle(.plain)
            .disabled(activeIndex == 0)

            Spacer()

            Button {
                Haptics.impact(.light)
                isGridOpen = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accentPrimary)
                    Text("\(answeredCount)/\(builtExam.items.count)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                    if !flaggedIds.isEmpty {
                        Text("\(flaggedIds.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(palette.accentSecondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(palette.bgSoftAccent)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(palette.bgMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            if activeIndex < builtExam.items.count - 1 {
                Button {
                    Haptics.impact(.light)
                    selectIndex(activeIndex + 1)
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                            .font(.system(size: 12.5, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(palette.accentPrimaryFg)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(palette.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Haptics.impact(.medium)
                    submitExam(autoSubmitted: false)
                } label: {
                    HStack(spacing: 5) {
                        Text("Finish")
                            .font(.system(size: 12.5, weight: .bold))
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(palette.statusCorrectSolidFg)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(palette.statusCorrectSolid)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(palette.bgSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.borderSubtle).frame(height: 1)
        }
    }

    // MARK: - Timing & Persistence

    private func commitElapsedForCurrentQuestion() {
        guard let currentQ = activeItem?.question else { return }
        let now = Date()
        let deltaMs = max(0, Int(now.timeIntervalSince(questionEnteredAt) * 1000.0))
        questionEnteredAt = now
        timeSpentByQuestionMs[currentQ.id, default: 0] += deltaMs
    }

    private func selectIndex(_ nextIndex: Int) {
        guard nextIndex >= 0 && nextIndex < builtExam.items.count && nextIndex != activeIndex else { return }
        commitElapsedForCurrentQuestion()
        activeIndex = nextIndex
    }

    private func submitExam(autoSubmitted: Bool) {
        guard !hasSubmitted else { return }
        hasSubmitted = true
        commitElapsedForCurrentQuestion()

        let completedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        let totalElapsedMs = max(1000, Int(completedAtMs - startedAtMs))

        var score = 0
        for item in builtExam.items {
            guard let selectedIdx = answers[item.question.id] else { continue }
            let isCorrect = selectedIdx == item.question.correctIndex
            if isCorrect { score += 1 }

            let selectedTrap: String? = isCorrect
                ? nil
                : ((selectedIdx >= 0 && selectedIdx < item.question.trapLabels.count
                    ? item.question.trapLabels[selectedIdx]
                    : nil) ?? "Distractor Trap")
            let qTimeMs = max(1000, timeSpentByQuestionMs[item.question.id] ?? 1500)

            let attempt = QuestionAttempt(
                questionId: item.question.id,
                topic: item.question.topic,
                isCorrect: isCorrect,
                timeSpentMs: qTimeMs,
                selectedTrap: selectedTrap,
                selectedOptionIndex: selectedIdx,
                source: .mock,
                timestampMs: completedAtMs
            )
            modelContext.insert(attempt)
        }

        let record = MockSessionRecord(
            startedAtMs: startedAtMs,
            completedAtMs: completedAtMs,
            passageIds: builtExam.passageIds,
            answers: answers,
            flaggedQuestionIds: Array(flaggedIds),
            timeSpentByQuestionMs: timeSpentByQuestionMs,
            totalElapsedMs: totalElapsedMs,
            score: score,
            totalQuestions: builtExam.items.count,
            status: "completed"
        )
        modelContext.insert(record)
        try? modelContext.save()

        onComplete(record.toDTO(), autoSubmitted)
    }
}
