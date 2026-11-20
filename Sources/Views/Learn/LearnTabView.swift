import SwiftData
import SwiftUI

public struct LearnTabView: View {
    @Environment(\.lnatPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Query private var completedRecords: [CompletedCardRecord]

    @Binding public var selectedTopic: LnatTopic?
    public let contentStore: ContentStore

    @State private var navPath: [LnatTopic] = []
    @State private var navHapticTrigger = 0
    @State private var activeCardIndex = 0
    @State private var isShowingCompletion = false
    @State private var slideByCard: [String: Int] = [:]
    @State private var sessionAnswersByCard: [String: Int] = [:]

    public init(
        selectedTopic: Binding<LnatTopic?>,
        contentStore: ContentStore = .shared
    ) {
        self._selectedTopic = selectedTopic
        self.contentStore = contentStore
    }

    private var completedSet: Set<String> {
        Set(completedRecords.map(\.cardId))
    }

    public var body: some View {
        NavigationStack(path: $navPath) {
            skillHubView
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: LnatTopic.self) { topic in
                    FocusedDeckView(
                        topic: topic,
                        cards: contentStore.cards(for: topic),
                        completedSet: completedSet,
                        activeCardIndex: $activeCardIndex,
                        isShowingCompletion: $isShowingCompletion,
                        slideByCard: $slideByCard,
                        sessionAnswersByCard: $sessionAnswersByCard,
                        onSelectNextTopic: { nextTopic in
                            selectedTopic = nextTopic
                        },
                        onRetestTopic: {
                            retestTopic(topic)
                        },
                        onRecordAnswer: { card, optionIndex, timeSpentMs, isCorrect, selectedTrap in
                            guard let drill = card.drill else { return }
                            sessionAnswersByCard[card.id] = optionIndex
                            StudyPersistence.recordFeedAnswer(
                                cardId: card.id,
                                questionId: drill.questionId,
                                topic: card.topic,
                                isCorrect: isCorrect,
                                timeSpentMs: timeSpentMs,
                                selectedTrap: selectedTrap,
                                selectedOptionIndex: optionIndex,
                                in: modelContext
                            )
                            slideByCard[card.id] = 3
                        },
                        onMarkCardCompleted: { cardId in
                            StudyPersistence.markCardCompleted(cardId, in: modelContext)
                        }
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bgApp)
        .onAppear {
            if let topic = selectedTopic, navPath != [topic] {
                navPath = [topic]
                resetDeckPosition(for: topic)
            }
        }
        .onChange(of: selectedTopic) { _, newTopic in
            let target = newTopic.map { [$0] } ?? []
            if navPath != target {
                navPath = target
            }
            resetDeckPosition(for: newTopic)
        }
        .onChange(of: navPath) { oldPath, newPath in
            if oldPath != newPath {
                navHapticTrigger += 1
            }
            let top = newPath.last
            if selectedTopic != top {
                selectedTopic = top
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: navHapticTrigger)
    }

    // MARK: - Level 1: 6-Skill Hub

    private var skillHubView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Section A Skills")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                    Text("Six foundational reasoning skills tested in Section A.")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.top, 4)

                VStack(spacing: 10) {
                    ForEach(LnatTopic.allCases) { topic in
                        skillCardRow(topic)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(palette.bgApp)
    }

    private func skillCardRow(_ topic: LnatTopic) -> some View {
        let cards = contentStore.cards(for: topic)
        let lessonsCount = cards.filter(\.isPrimer).count
        let drillsCount = cards.count - lessonsCount
        let completedCount = cards.filter { card in
            completedSet.contains(card.id) || sessionAnswersByCard[card.id] != nil
        }.count
        let isComplete = !cards.isEmpty && completedCount == cards.count

        let statusText = completedCount == 0
            ? "\(lessonsCount) lessons · \(drillsCount) drills"
            : "\(completedCount) of \(cards.count) completed"

        return NavigationLink(value: topic) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(topic.rawValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                }

                Text(topic.description)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                    }
                    Text(statusText)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(
                    isComplete
                        ? palette.statusCorrectText
                        : (completedCount > 0 ? palette.accentSecondaryText : palette.textSecondary)
                )
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.borderSubtle, lineWidth: 1)
            )
            .shadow(color: palette.isDark ? .black.opacity(0.2) : palette.textPrimary.opacity(0.03), radius: 6, x: 0, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(TactileCardButtonStyle())
    }

    // MARK: - Navigation State Actions

    private func resetDeckPosition(for topic: LnatTopic?) {
        isShowingCompletion = false
        guard let topic else {
            activeCardIndex = 0
            return
        }
        let cards = contentStore.cards(for: topic)
        let firstIncomplete = cards.firstIndex { !completedSet.contains($0.id) }
        activeCardIndex = firstIncomplete ?? 0
    }

    private func retestTopic(_ topic: LnatTopic) {
        let cards = contentStore.cards(for: topic)
        let ids = Set(cards.map(\.id))
        for id in ids {
            sessionAnswersByCard.removeValue(forKey: id)
            slideByCard[id] = 0
        }
        StudyPersistence.unmarkCardsCompleted(ids, in: modelContext)
        isShowingCompletion = false
        activeCardIndex = 0
    }
}

// MARK: - Level 2: Focused Deck View

public struct FocusedDeckView: View {
    @Environment(\.lnatPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    public let topic: LnatTopic
    public let cards: [StoryCard]
    public let completedSet: Set<String>
    @Binding public var activeCardIndex: Int
    @Binding public var isShowingCompletion: Bool
    @Binding public var slideByCard: [String: Int]
    @Binding public var sessionAnswersByCard: [String: Int]

    public let onSelectNextTopic: (LnatTopic) -> Void
    public let onRetestTopic: () -> Void
    public let onRecordAnswer: (_ card: StoryCard, _ optionIndex: Int, _ timeSpentMs: Int, _ isCorrect: Bool, _ selectedTrap: String?) -> Void
    public let onMarkCardCompleted: (String) -> Void

    public init(
        topic: LnatTopic,
        cards: [StoryCard],
        completedSet: Set<String>,
        activeCardIndex: Binding<Int>,
        isShowingCompletion: Binding<Bool>,
        slideByCard: Binding<[String: Int]>,
        sessionAnswersByCard: Binding<[String: Int]>,
        onSelectNextTopic: @escaping (LnatTopic) -> Void,
        onRetestTopic: @escaping () -> Void,
        onRecordAnswer: @escaping (_ card: StoryCard, _ optionIndex: Int, _ timeSpentMs: Int, _ isCorrect: Bool, _ selectedTrap: String?) -> Void,
        onMarkCardCompleted: @escaping (String) -> Void
    ) {
        self.topic = topic
        self.cards = cards
        self.completedSet = completedSet
        self._activeCardIndex = activeCardIndex
        self._isShowingCompletion = isShowingCompletion
        self._slideByCard = slideByCard
        self._sessionAnswersByCard = sessionAnswersByCard
        self.onSelectNextTopic = onSelectNextTopic
        self.onRetestTopic = onRetestTopic
        self.onRecordAnswer = onRecordAnswer
        self.onMarkCardCompleted = onMarkCardCompleted
    }

    public var body: some View {
        let safeIndex = min(activeCardIndex, max(0, cards.count - 1))
        let activeCard = cards.isEmpty ? nil : cards[safeIndex]
        let nextCard = safeIndex + 1 < cards.count ? cards[safeIndex + 1] : nil

        let progressLabel: String = {
            guard !isShowingCompletion, let card = activeCard else { return "Completed" }
            if card.isPrimer {
                let primers = cards.filter(\.isPrimer)
                let idx = (primers.firstIndex(where: { $0.id == card.id }) ?? 0) + 1
                return "Lesson \(idx) of \(primers.count)"
            } else {
                let drills = cards.filter { !$0.isPrimer }
                let idx = (drills.firstIndex(where: { $0.id == card.id }) ?? 0) + 1
                return "Drill \(idx) of \(drills.count)"
            }
        }()

        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Skills")
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundStyle(palette.accentPrimary)
                    .frame(minHeight: 44)
                    .padding(.trailing, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(progressLabel)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
            .background(palette.bgSurface.opacity(0.9))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.borderSubtle)
                    .frame(height: 1)
            }

            if isShowingCompletion || activeCard == nil {
                completionView
            } else if let card = activeCard {
                StoryCardView(
                    card: card,
                    slideIndex: slideByCard[card.id] ?? 0,
                    isCardCompleted: completedSet.contains(card.id) || sessionAnswersByCard[card.id] != nil,
                    chosenOptionIndex: sessionAnswersByCard[card.id],
                    hasPrevCard: safeIndex > 0,
                    hasNextCard: safeIndex < cards.count - 1,
                    hasNextPrimerInTopic: card.isPrimer && (nextCard?.isPrimer ?? false),
                    onChangeSlide: { nextSlide in
                        slideByCard[card.id] = nextSlide
                    },
                    onAnswer: { optionIndex, timeSpentMs, isCorrect, selectedTrap in
                        onRecordAnswer(card, optionIndex, timeSpentMs, isCorrect, selectedTrap)
                    },
                    onPrevCard: {
                        if safeIndex > 0 {
                            let prevIdx = safeIndex - 1
                            let prevCard = cards[prevIdx]
                            slideByCard[prevCard.id] = 3
                            activeCardIndex = prevIdx
                        }
                    },
                    onNextCard: {
                        handleNextFromCard(card, safeIndex: safeIndex)
                    },
                    onStartDrills: card.isPrimer ? {
                        onMarkCardCompleted(card.id)
                        let firstDrillIdx = cards.firstIndex(where: { !$0.isPrimer }) ?? min(cards.count - 1, safeIndex + 1)
                        if firstDrillIdx < cards.count {
                            slideByCard[cards[firstDrillIdx].id] = 0
                        }
                        activeCardIndex = firstDrillIdx
                    } : nil
                )
                .id(card.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bgApp)
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractivePopGesture()
    }

    private var completionView: some View {
        let nextTopic = topic.nextTopic
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(palette.statusCorrectText)
                    .frame(width: 52, height: 52)
                    .background(palette.statusCorrectBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.statusCorrectBorder, lineWidth: 1)
                    )

                VStack(spacing: 6) {
                    Text("\(topic.rawValue) Completed")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                    Text("You have finished both lessons and all three practice drills for this skill.")
                        .font(.system(size: 13.5))
                        .lineSpacing(3.5)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button {
                        Haptics.impact(.medium)
                        onSelectNextTopic(nextTopic)
                    } label: {
                        HStack(spacing: 8) {
                            Text("Next Skill: \(nextTopic.rawValue)")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(palette.accentPrimaryFg)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(palette.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.impact(.light)
                        onRetestTopic()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Practice Again")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(palette.bgMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(palette.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Text("Back to Skills")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
            .padding(24)
            .background(palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.borderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    private func handleNextFromCard(_ card: StoryCard, safeIndex: Int) {
        if card.isPrimer {
            onMarkCardCompleted(card.id)
        }
        if safeIndex < cards.count - 1 {
            let nextIdx = safeIndex + 1
            slideByCard[cards[nextIdx].id] = 0
            activeCardIndex = nextIdx
        } else {
            isShowingCompletion = true
        }
    }
}
