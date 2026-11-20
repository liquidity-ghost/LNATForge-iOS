import SwiftData
import SwiftUI

public struct ProgressTabView: View {
    @Environment(\.lnatPalette) private var palette
    @Query(sort: \QuestionAttempt.timestampMs) private var attempts: [QuestionAttempt]
    @Query private var mockSessions: [MockSessionRecord]
    @Query private var outlines: [SavedOutline]
    @Query private var completedCards: [CompletedCardRecord]

    @Binding public var themeModeRaw: String
    public let contentStore: ContentStore
    public let onTrainTopic: (LnatTopic) -> Void
    public let onSettingsOpenChanged: ((Bool) -> Void)?

    @State private var isSettingsOpen = false

    public init(
        themeModeRaw: Binding<String>,
        contentStore: ContentStore = .shared,
        onTrainTopic: @escaping (LnatTopic) -> Void,
        onSettingsOpenChanged: ((Bool) -> Void)? = nil
    ) {
        self._themeModeRaw = themeModeRaw
        self.contentStore = contentStore
        self.onTrainTopic = onTrainTopic
        self.onSettingsOpenChanged = onSettingsOpenChanged
    }

    private var telemetryDTOs: [QuestionTelemetryDTO] {
        attempts.compactMap { $0.toDTO() }
    }

    private var overall: OverallStats {
        DiagnosticsEngine.computeOverallStats(
            telemetry: telemetryDTOs,
            primerCardIds: contentStore.primerCardIds,
            validGradedQuestionIds: contentStore.validGradedQuestionIds
        )
    }

    private var topicMastery: [TopicMastery] {
        DiagnosticsEngine.computeAllTopicMastery(
            telemetry: telemetryDTOs,
            primerCardIds: contentStore.primerCardIds,
            validGradedQuestionIds: contentStore.validGradedQuestionIds
        )
    }

    public var body: some View {
        let stats = overall
        let masteryList = topicMastery

        VStack(spacing: 0) {
            headerBar
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)

            kpiStrip(stats)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if stats.totalAttempted == 0 {
                        emptyStateCard
                    } else {
                        needsFocusCard(stats)
                    }

                    allSkillsSection(stats: stats, masteryList: masteryList)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bgApp)
        .onChange(of: isSettingsOpen) { _, open in
            onSettingsOpenChanged?(open)
        }
        .sheet(isPresented: $isSettingsOpen) {
            SettingsSheetView(
                themeModeRaw: $themeModeRaw,
                questionsCount: stats.totalAttempted,
                completedCardsCount: Set(completedCards.map(\.cardId)).count,
                mockSessionsCount: mockSessions.count,
                outlinesCount: outlines.count
            )
            .environment(\.lnatPalette, palette)
        }
    }

    // MARK: - Header & KPIs

    private var headerBar: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your Progress")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Text("Mastery: 80%+ across \(DiagnosticsEngine.masteryMinAttempts) questions")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            Button {
                Haptics.impact(.light)
                isSettingsOpen = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.accentPrimary)
                    Text("Settings")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 38)
                .background(palette.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func kpiStrip(_ stats: OverallStats) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Answered")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                Text("\(stats.totalAttempted)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Text(formatSourceBreakdown(drills: stats.feedAttempted, tests: stats.mockAttempted))
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text("Accuracy")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                Text("\(stats.accuracyPercent)%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.accentSecondaryText)
                Text("\(stats.totalCorrect) of \(stats.totalAttempted) correct")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text("Avg. Time")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                Text(stats.totalAttempted == 0 ? "—" : "\(stats.avgTimeSeconds)s")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        stats.totalAttempted == 0
                            ? palette.textPrimary
                            : (stats.isOverallSlowPace ? palette.statusTrapText : palette.statusCorrectText)
                    )
                Text("Target: \(DiagnosticsEngine.targetPaceSeconds)s")
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))
        }
    }

    // MARK: - Empty State & Needs Focus

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 20))
                .foregroundStyle(palette.accentSecondaryText)
                .frame(width: 44, height: 44)
                .background(palette.bgSoftAccent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))

            VStack(spacing: 4) {
                Text("No Questions Answered Yet")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Text("Complete a few practice drills in Learn or take a practice paper in Review to see your focus areas and mistake patterns here.")
                    .font(.system(size: 13))
                    .lineSpacing(3.5)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Haptics.impact(.medium)
                onTrainTopic(.mainConclusion)
            } label: {
                HStack(spacing: 6) {
                    Text("Start Learning")
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
        }
        .padding(20)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))
    }

    private func needsFocusCard(_ stats: OverallStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Needs Focus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.textPrimary)

                Spacer()

                if stats.slowTopicsCount > 0 {
                    Text("\(stats.slowTopicsCount) slow skill\(stats.slowTopicsCount > 1 ? "s" : "")")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(palette.statusTrapText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(palette.statusTrapBg)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(palette.statusTrapBorder, lineWidth: 1))
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.statusTrapText)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MOST COMMON MISTAKE")
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(0.5)
                        .opacity(0.85)
                    Text(
                        stats.topTrap.map { "\($0.trap) (\($0.count))" } ?? "No mistakes recorded yet"
                    )
                    .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(palette.statusTrapText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.statusTrapBg)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.statusTrapBorder, lineWidth: 1))

            VStack(spacing: 8) {
                ForEach(stats.weakestTopics) { weak in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(weak.topic.rawValue)
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundStyle(palette.textPrimary)
                                if weak.isSlowPace {
                                    Text("Over \(DiagnosticsEngine.targetPaceSeconds)s")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(palette.statusTrapText)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(palette.statusTrapBg)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(palette.statusTrapBorder, lineWidth: 1))
                                }
                            }

                            let trapSuffix = weak.topTrap.map { " · \($0.trap)" } ?? ""
                            Text(weak.reasonLabel + trapSuffix)
                                .font(.system(size: 12))
                                .foregroundStyle(palette.textSecondary)
                        }

                        Spacer()

                        Button {
                            Haptics.impact(.light)
                            onTrainTopic(weak.topic)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Practice")
                                    .font(.system(size: 12, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(palette.accentPrimary)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(palette.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(palette.bgMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))
                }
            }

            if let primary = stats.weakestTopics.first {
                Button {
                    Haptics.impact(.medium)
                    onTrainTopic(primary.topic)
                } label: {
                    HStack(spacing: 8) {
                        Text("Practice \(primary.topic.rawValue)")
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
            }
        }
        .padding(14)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accentSecondary.opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - All Skills Breakdown

    private func allSkillsSection(stats: OverallStats, masteryList: [TopicMastery]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ALL SKILLS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Text("\(stats.masteredCount) of 6 mastered")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.horizontal, 2)

            ForEach(masteryList) { item in
                skillMasteryCard(item)
            }
        }
    }

    private func skillMasteryCard(_ item: TopicMastery) -> some View {
        let pct = item.masteryPercent
        let statusBg: Color
        let statusBorder: Color
        let statusFg: Color
        switch item.status {
        case .mastered:
            statusBg = palette.statusCorrectBg
            statusBorder = palette.statusCorrectBorder
            statusFg = palette.statusCorrectText
        case .nearMastery:
            statusBg = palette.bgSoftAccent
            statusBorder = palette.accentSecondary.opacity(0.5)
            statusFg = palette.accentSecondaryText
        case .inProgress, .notStarted:
            statusBg = palette.bgMuted
            statusBorder = palette.borderSubtle
            statusFg = palette.textSecondary
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                HStack(spacing: 6) {
                    if item.isMastered {
                        Image(systemName: "rosette")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.statusCorrectText)
                    }
                    Text(item.topic.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if item.isSlowPace {
                        Text("Over \(DiagnosticsEngine.targetPaceSeconds)s")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(palette.statusTrapText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(palette.statusTrapBg)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(palette.statusTrapBorder, lineWidth: 1))
                    }

                    Text(item.status.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusFg)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(statusBg)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(statusBorder, lineWidth: 1))
                }
            }

            GeometryReader { geo in
                let fillFraction = item.attempted == 0 ? 0.0 : max(0.06, Double(pct) / 100.0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.bgSoftAccent)
                    Capsule()
                        .fill(item.isMastered ? palette.accentBlue : palette.accentSecondary)
                        .frame(width: geo.size.width * min(1.0, fillFraction))
                    Rectangle()
                        .fill(palette.textPrimary.opacity(0.4))
                        .frame(width: 2)
                        .offset(x: geo.size.width * 0.80)
                }
            }
            .frame(height: 8)

            HStack {
                Text(
                    item.attempted == 0
                        ? "Not started yet"
                        : "\(item.correct) of \(item.attempted) correct (\(pct)%) · \(formatSourceBreakdown(drills: item.feedAttempted, tests: item.mockAttempted))"
                )
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)

                Spacer()

                if item.attempted > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("\(item.avgTimeSeconds)s")
                            .font(.system(size: 12, weight: item.isSlowPace ? .semibold : .regular, design: .monospaced))
                    }
                    .foregroundStyle(item.isSlowPace ? palette.statusTrapText : palette.textSecondary)
                }
            }

            HStack(spacing: 8) {
                if let topTrap = item.frequentTraps.first {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .padding(.top, 2)
                        Text("\(topTrap.trap) (\(topTrap.count))")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(palette.statusTrapText)
                } else {
                    Text(
                        item.attempted < DiagnosticsEngine.masteryMinAttempts
                            ? "\(DiagnosticsEngine.masteryMinAttempts - item.attempted) more questions to reach mastery"
                            : "On track for mastery"
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
                }

                Spacer()

                Button {
                    Haptics.impact(.light)
                    onTrainTopic(item.topic)
                } label: {
                    HStack(spacing: 4) {
                        Text("Practice")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(palette.accentPrimary)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))
    }

    private func formatSourceBreakdown(drills: Int, tests: Int) -> String {
        let drillWord = drills == 1 ? "drill" : "drills"
        let testWord = tests == 1 ? "test" : "tests"
        return "\(drills) \(drillWord) · \(tests) \(testWord)"
    }
}
