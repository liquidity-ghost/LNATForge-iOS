import SwiftUI

public struct StoryCardView: View {
    @Environment(\.lnatPalette) private var palette

    public let card: StoryCard
    public let slideIndex: Int
    public let isCardCompleted: Bool
    public let chosenOptionIndex: Int?
    public let hasPrevCard: Bool
    public let hasNextCard: Bool
    public let hasNextPrimerInTopic: Bool

    public let onChangeSlide: (Int) -> Void
    public let onAnswer: (_ optionIndex: Int, _ timeSpentMs: Int, _ isCorrect: Bool, _ selectedTrap: String?) -> Void
    public let onPrevCard: () -> Void
    public let onNextCard: () -> Void
    public let onStartDrills: (() -> Void)?

    @State private var drillNudge = false
    @State private var drillSlideEnteredAt = Date()
    @State private var drillSuccessTrigger = 0
    @State private var drillErrorTrigger = 0
    @State private var slidePillSelectTrigger = 0

    private let optionLetters = ["A", "B", "C", "D"]
    private let drillSlideTitles = ["The Argument", "Key Clue", "Question", "Trap Breakdown"]
    private let primerSlideTitles = ["The Concept", "How to Spot It", "Example", "Common Traps"]

    private var isPrimer: Bool { card.isPrimer }
    private var slideTitles: [String] { isPrimer ? primerSlideTitles : drillSlideTitles }
    private var isAnswered: Bool { !isPrimer && chosenOptionIndex != nil }
    private var isSlide4Unlocked: Bool { isPrimer || isAnswered || isCardCompleted }
    private var canGoBack: Bool { slideIndex > 0 || hasPrevCard }

    public init(
        card: StoryCard,
        slideIndex: Int,
        isCardCompleted: Bool,
        chosenOptionIndex: Int?,
        hasPrevCard: Bool,
        hasNextCard: Bool,
        hasNextPrimerInTopic: Bool,
        onChangeSlide: @escaping (Int) -> Void,
        onAnswer: @escaping (_ optionIndex: Int, _ timeSpentMs: Int, _ isCorrect: Bool, _ selectedTrap: String?) -> Void,
        onPrevCard: @escaping () -> Void,
        onNextCard: @escaping () -> Void,
        onStartDrills: (() -> Void)? = nil
    ) {
        self.card = card
        self.slideIndex = slideIndex
        self.isCardCompleted = isCardCompleted
        self.chosenOptionIndex = chosenOptionIndex
        self.hasPrevCard = hasPrevCard
        self.hasNextCard = hasNextCard
        self.hasNextPrimerInTopic = hasNextPrimerInTopic
        self.onChangeSlide = onChangeSlide
        self.onAnswer = onAnswer
        self.onPrevCard = onPrevCard
        self.onNextCard = onNextCard
        self.onStartDrills = onStartDrills
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                stepHeader
                    .padding(.bottom, 12)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            Color.clear.frame(height: 0).id("slideTop")
                            slideContent
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: slideIndex) { _, newValue in
                        drillNudge = false
                        if !isPrimer && newValue == 2 && !isAnswered {
                            drillSlideEnteredAt = Date()
                        }
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("slideTop", anchor: .top)
                        }
                    }
                    .onChange(of: card.id) { _, _ in
                        drillNudge = false
                        drillSlideEnteredAt = Date()
                        proxy.scrollTo("slideTop", anchor: .top)
                    }
                }

                bottomNavigation
                    .padding(.top, 12)
            }
            .padding(16)
            .background(palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.borderSubtle, lineWidth: 1)
            )
            .shadow(color: palette.isDark ? .black.opacity(0.28) : palette.textPrimary.opacity(0.05), radius: 10, x: 0, y: 4)
            .simultaneousGesture(
                DragGesture(minimumDistance: 24, coordinateSpace: .global)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        if dx > 0 && value.startLocation.x < 32 { return }
                        guard abs(dx) > 44, abs(dx) > abs(dy) * 1.2 else { return }
                        if dx < 0 {
                            goToNextSlide()
                        } else if slideIndex > 0 {
                            Haptics.impact(.light)
                            onChangeSlide(slideIndex - 1)
                        }
                    }
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .onAppear {
            if !isPrimer && slideIndex == 2 && !isAnswered {
                drillSlideEnteredAt = Date()
            }
        }
        .sensoryFeedback(.success, trigger: drillSuccessTrigger)
        .sensoryFeedback(.error, trigger: drillErrorTrigger)
        .sensoryFeedback(.selection, trigger: slidePillSelectTrigger)
    }

    // MARK: - Top 4-Segment Progress Bar & Badge

    private var stepHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { idx in
                    let isLocked = idx == 3 && !isSlide4Unlocked
                    let isActive = slideIndex == idx
                    let isCompletedSeg = slideIndex > idx

                    Button {
                        guard !isLocked else {
                            Haptics.warning()
                            drillNudge = true
                            return
                        }
                        slidePillSelectTrigger += 1
                        onChangeSlide(idx)
                    } label: {
                        Capsule()
                            .fill(
                                isActive
                                    ? palette.accentSecondary
                                    : (isCompletedSeg ? palette.accentBlue : palette.bgSoftAccent)
                            )
                            .frame(height: 5)
                            .opacity(isLocked ? 0.45 : 1.0)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(slideTitles[idx])
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: isPrimer ? "book.fill" : "scope")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isPrimer ? "Lesson" : "Drill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isPrimer ? palette.bgSoftAccent : palette.bgMuted)
                .foregroundStyle(isPrimer ? palette.accentSecondaryText : palette.accentBlueText)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.borderSubtle, lineWidth: 1)
                )

                Spacer()

                Text(slideTitles[min(max(0, slideIndex), 3)])
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    // MARK: - Slide Bodies

    @ViewBuilder
    private var slideContent: some View {
        switch slideIndex {
        case 0:
            slide1View
        case 1:
            slide2View
        case 2:
            if isPrimer {
                slide3WorkedExampleView
            } else {
                slide3DrillView
            }
        default:
            if isPrimer {
                slide4PrimerBreakdownView
            } else {
                slide4DrillBreakdownView
            }
        }
    }

    private var slide1View: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(card.slide1_hook.headline)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(card.slide1_hook.claimText)
                    .font(.system(size: 16, design: .serif))
                    .lineSpacing(6)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            calloutBox(
                title: "Key Takeaway",
                body: card.slide1_hook.ruleTakeaway,
                titleColor: isPrimer ? palette.accentSecondaryText : palette.accentPrimary,
                fillColor: isPrimer ? palette.bgSoftAccent.opacity(0.65) : palette.bgMuted
            )
        }
    }

    private var slide2View: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(card.slide2_spotlight.qualifierTag)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accentSecondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.bgMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(palette.borderSubtle, lineWidth: 1)
                    )

                Text(card.slide2_spotlight.contextText)
                    .font(.system(size: 14.5))
                    .lineSpacing(4)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(isPrimer ? palette.accentSecondary : palette.accentBlue)
                        .frame(width: 4)

                    Text(
                        isPrimer
                            ? card.slide2_spotlight.highlightedSegment
                            : "“\(card.slide2_spotlight.highlightedSegment)”"
                    )
                    .font(
                        isPrimer
                            ? .system(size: 16, weight: .semibold)
                            : .system(size: 16, design: .serif)
                    )
                    .lineSpacing(5)
                    .foregroundStyle(palette.textPrimary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(isPrimer ? palette.bgSoftAccent.opacity(0.65) : palette.bgMuted)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            calloutBox(
                title: "What to Look For",
                body: card.slide2_spotlight.focusNote,
                titleColor: isPrimer ? palette.accentSecondaryText : palette.accentPrimary,
                fillColor: palette.bgMuted
            )
        }
    }

    private var slide3WorkedExampleView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let worked = card.workedExample {
                Text(worked.highlightLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accentBlueText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.bgMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(palette.borderSubtle, lineWidth: 1)
                    )

                Text(highlightedArgument(worked.argumentText, segment: worked.highlightedSegment))
                    .font(.system(size: 16, design: .serif))
                    .lineSpacing(6)
                    .foregroundStyle(palette.textPrimary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.bgMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.borderSubtle, lineWidth: 1)
                    )

                calloutBox(
                    title: "Why It Works",
                    body: worked.annotation,
                    titleColor: palette.accentSecondaryText,
                    fillColor: palette.bgSoftAccent.opacity(0.65)
                )
            }
        }
    }

    private var slide3DrillView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let drill = card.drill {
                Text(drill.stem)
                    .font(.system(size: 15.5, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(Array(drill.options.enumerated()), id: \.offset) { idx, option in
                        drillOptionButton(drill: drill, idx: idx, option: option)
                    }
                }

                if drillNudge && !isSlide4Unlocked {
                    Text("Choose an answer to see the explanation.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.accentSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func drillOptionButton(drill: StorySlide3Drill, idx: Int, option: String) -> some View {
        let isSelected = chosenOptionIndex == idx
        let isCorrectOpt = idx == drill.correctIndex

        let bgColor: Color
        let borderColor: Color
        let textColor: Color
        let badgeBg: Color
        let badgeBorder: Color
        let badgeText: Color

        if isAnswered {
            if isCorrectOpt {
                bgColor = palette.statusCorrectBg
                borderColor = palette.statusCorrectBorder
                textColor = palette.statusCorrectText
                badgeBg = palette.statusCorrectSolid
                badgeBorder = palette.statusCorrectSolid
                badgeText = palette.statusCorrectSolidFg
            } else if isSelected {
                bgColor = palette.statusTrapBg
                borderColor = palette.statusTrapBorder
                textColor = palette.statusTrapText
                badgeBg = palette.statusTrapSolid
                badgeBorder = palette.statusTrapSolid
                badgeText = palette.statusTrapSolidFg
            } else {
                bgColor = palette.bgMuted.opacity(0.55)
                borderColor = palette.borderSubtle.opacity(0.6)
                textColor = palette.textSecondary.opacity(0.75)
                badgeBg = palette.bgSoftAccent
                badgeBorder = palette.borderSubtle
                badgeText = palette.accentSecondaryText
            }
        } else {
            bgColor = palette.bgMuted
            borderColor = palette.borderSubtle
            textColor = palette.textPrimary
            badgeBg = palette.bgSoftAccent
            badgeBorder = palette.borderSubtle
            badgeText = palette.accentSecondaryText
        }

        return Button {
            guard !isAnswered else { return }
            let elapsedMs = max(250, Int(Date().timeIntervalSince(drillSlideEnteredAt) * 1000.0))
            let isCorrect = idx == drill.correctIndex
            let selectedTrap: String? = isCorrect ? nil : (idx < drill.trapLabels.count ? drill.trapLabels[idx] : nil)
            if isCorrect {
                drillSuccessTrigger += 1
            } else {
                drillErrorTrigger += 1
            }
            onAnswer(idx, elapsedMs, isCorrect, selectedTrap)
        } label: {
            HStack(spacing: 12) {
                Text(optionLetters[idx])
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(badgeText)
                    .frame(width: 26, height: 26)
                    .background(badgeBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(badgeBorder, lineWidth: 1)
                    )

                Text(option)
                    .font(.system(size: 13.5))
                    .lineSpacing(2)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isAnswered && isCorrectOpt {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(palette.statusCorrectText)
                } else if isAnswered && isSelected && !isCorrectOpt {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(palette.statusTrapText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 48)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnswered)
    }

    private var slide4PrimerBreakdownView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let breakdown = card.primerBreakdown {
                Text(breakdown.logicSummary)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(breakdown.commonTraps) { trap in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(palette.statusTrapText)
                                    .padding(.top, 2)
                                Text(trap.trapName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(palette.statusTrapText)
                            }
                            Text(trap.howToSpot)
                                .font(.system(size: 12.5))
                                .lineSpacing(3)
                                .foregroundStyle(palette.textPrimary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.statusTrapBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(palette.statusTrapBorder, lineWidth: 1)
                        )
                    }
                }

                calloutBox(
                    title: "Key Takeaway",
                    body: breakdown.examTakeaway,
                    titleColor: palette.accentPrimary,
                    fillColor: palette.bgMuted
                )
            }
        }
    }

    private var slide4DrillBreakdownView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let drill = card.drill, let breakdown = card.drillBreakdown {
                let isChosenCorrect = chosenOptionIndex == drill.correctIndex

                HStack(spacing: 6) {
                    if isAnswered {
                        Image(systemName: isChosenCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isChosenCorrect ? "Correct" : "Incorrect")
                            .font(.system(size: 12, weight: .bold))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Completed")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundStyle((!isAnswered || isChosenCorrect) ? palette.statusCorrectText : palette.statusTrapText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((!isAnswered || isChosenCorrect) ? palette.statusCorrectBg : palette.statusTrapBg)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke((!isAnswered || isChosenCorrect) ? palette.statusCorrectBorder : palette.statusTrapBorder, lineWidth: 1)
                )

                Text(breakdown.logicSummary)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(palette.textPrimary)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.statusTrapText)
                        .padding(.top, 2)
                    Text(breakdown.primaryTrap)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineSpacing(3)
                        .foregroundStyle(palette.statusTrapText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.statusTrapBg)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.statusTrapBorder, lineWidth: 1)
                )

                VStack(spacing: 8) {
                    ForEach(Array(breakdown.optionBreakdowns.enumerated()), id: \.offset) { idx, note in
                        let isCorrectOpt = idx == drill.correctIndex
                        let isChosenWrong = chosenOptionIndex == idx && !isCorrectOpt

                        Text(note)
                            .font(.system(size: 12.5))
                            .lineSpacing(3)
                            .foregroundStyle(
                                isCorrectOpt
                                    ? palette.statusCorrectText
                                    : (isChosenWrong ? palette.statusTrapText : palette.textSecondary)
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                isCorrectOpt
                                    ? palette.statusCorrectBg
                                    : (isChosenWrong ? palette.statusTrapBg : palette.bgMuted)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        isCorrectOpt
                                            ? palette.statusCorrectBorder
                                            : (isChosenWrong ? palette.statusTrapBorder : palette.borderSubtle.opacity(0.6)),
                                        lineWidth: 1
                                    )
                            )
                    }
                }

                calloutBox(
                    title: "Key Takeaway",
                    body: breakdown.examTakeaway,
                    titleColor: palette.accentBlueText,
                    fillColor: palette.bgMuted
                )
            }
        }
    }

    // MARK: - Bottom Navigation

    private var bottomNavigation: some View {
        HStack(spacing: 10) {
            Button {
                goToPreviousSlide()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(palette.bgMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.borderSubtle, lineWidth: 1)
                )
                .opacity(canGoBack ? 1.0 : 0.35)
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)

            primaryActionButton
        }
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if slideIndex < 2 {
            nextButton(label: "Next") { goToNextSlide() }
        } else if slideIndex == 2 {
            if !isPrimer && !isSlide4Unlocked {
                Button {
                    Haptics.warning()
                    drillNudge = true
                } label: {
                    Text("Select an Answer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(palette.bgMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(palette.borderSubtle, lineWidth: 1)
                        )
                        .opacity(0.75)
                }
                .buttonStyle(.plain)
            } else {
                nextButton(label: "Next") { goToNextSlide() }
            }
        } else if isPrimer {
            if hasNextPrimerInTopic {
                nextButton(label: "Next Lesson") {
                    Haptics.impact(.light)
                    onNextCard()
                }
            } else {
                nextButton(label: "Start Drills") {
                    Haptics.impact(.medium)
                    if let onStartDrills {
                        onStartDrills()
                    } else {
                        onNextCard()
                    }
                }
            }
        } else {
            nextButton(label: hasNextCard ? "Next Drill" : "Finish Skill") {
                Haptics.impact(.medium)
                onNextCard()
            }
        }
    }

    private func nextButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(palette.accentPrimaryFg)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(palette.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func goToPreviousSlide() {
        if slideIndex > 0 {
            Haptics.impact(.light)
            onChangeSlide(slideIndex - 1)
        } else if hasPrevCard {
            Haptics.impact(.light)
            onPrevCard()
        }
    }

    private func goToNextSlide() {
        if !isPrimer && slideIndex == 2 && !isSlide4Unlocked {
            Haptics.warning()
            drillNudge = true
            return
        }
        if slideIndex < 3 {
            Haptics.impact(.light)
            onChangeSlide(slideIndex + 1)
        }
    }

    private func calloutBox(
        title: String,
        body: String,
        titleColor: Color,
        fillColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(titleColor)
            Text(body)
                .font(.system(size: 13.5))
                .lineSpacing(3.5)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fillColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
    }

    private func highlightedArgument(_ text: String, segment: String) -> AttributedString {
        var attr = AttributedString(text)
        guard !segment.isEmpty, let range = attr.range(of: segment) else {
            return attr
        }
        attr[range].backgroundColor = palette.bgSoftAccent
        attr[range].foregroundColor = palette.textPrimary
        attr[range].font = .system(size: 16, weight: .semibold, design: .serif)
        return attr
    }
}
