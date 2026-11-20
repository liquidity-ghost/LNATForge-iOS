import SwiftData
import SwiftUI

public enum ReviewDestination: Hashable {
    case passage(MockPassage)
    case pastAttempt(MockExamSessionDTO)
}

private enum ReviewCoverRoute: Identifiable {
    case exam(BuiltMockExam)
    case review(session: MockExamSessionDTO, autoSubmitted: Bool)

    var id: String {
        switch self {
        case let .exam(built): return "exam-\(built.id.uuidString)"
        case let .review(session, _): return "review-\(session.id)"
        }
    }
}

private struct MockSessionCoverContainer: View {
    let initialRoute: ReviewCoverRoute
    let passages: [MockPassage]
    let onDismiss: () -> Void

    @State private var currentRoute: ReviewCoverRoute
    @State private var examSuccessTrigger = 0
    @State private var examErrorTrigger = 0

    init(
        initialRoute: ReviewCoverRoute,
        passages: [MockPassage],
        onDismiss: @escaping () -> Void
    ) {
        self.initialRoute = initialRoute
        self.passages = passages
        self.onDismiss = onDismiss
        self._currentRoute = State(initialValue: initialRoute)
    }

    var body: some View {
        Group {
            switch currentRoute {
            case let .exam(built):
                MockExamRunnerView(
                    builtExam: built,
                    onComplete: { dto, autoSubmitted in
                        let passed = (dto.score ?? 0) * 4 >= max(1, dto.totalQuestions) * 3
                        if passed {
                            examSuccessTrigger += 1
                        } else {
                            examErrorTrigger += 1
                        }
                        currentRoute = .review(session: dto, autoSubmitted: autoSubmitted)
                    },
                    onExit: onDismiss
                )
            case let .review(session, autoSubmitted):
                MockReviewView(
                    session: session,
                    passages: passages,
                    autoSubmitted: autoSubmitted,
                    onBackToLaunch: onDismiss
                )
            }
        }
        .sensoryFeedback(.success, trigger: examSuccessTrigger)
        .sensoryFeedback(.error, trigger: examErrorTrigger)
    }
}

public struct ReviewTabView: View {
    @Environment(\.lnatPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MockSessionRecord.startedAtMs, order: .reverse) private var mockSessions: [MockSessionRecord]

    public let contentStore: ContentStore
    @Binding public var isAtRoot: Bool
    public let resetToRootTrigger: Int

    @State private var navPath: [ReviewDestination] = []
    @State private var navHapticTrigger = 0
    @State private var activeCover: ReviewCoverRoute?

    public init(
        contentStore: ContentStore = .shared,
        isAtRoot: Binding<Bool> = .constant(true),
        resetToRootTrigger: Int = 0
    ) {
        self.contentStore = contentStore
        self._isAtRoot = isAtRoot
        self.resetToRootTrigger = resetToRootTrigger
    }

    private var completedSessions: [MockSessionRecord] {
        mockSessions.filter { session in
            session.status == "completed"
                && session.passageIds.contains(where: { contentStore.passageIdSet.contains($0) })
        }
    }

    public var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Practice Papers")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Timed full-length papers and focused reading sessions.")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 2)

                    launchCard(
                        title: "Official Test Version 1",
                        subtitle: "12 passages · 42 questions · 95 mins",
                        buttonTitle: "Start Test",
                        iconName: "play.fill",
                        isPrimary: true
                    ) {
                        startExam(.paper1)
                    }

                    launchCard(
                        title: "Official Test Version 2",
                        subtitle: "12 passages · 42 questions · 95 mins",
                        buttonTitle: "Start Test",
                        iconName: "play.fill",
                        isPrimary: true
                    ) {
                        startExam(.paper2)
                    }

                    launchCard(
                        title: "Quick Session",
                        subtitle: "2 passages · 18 mins",
                        detail: "Two fresh passages for a focused daily pacing session.",
                        buttonTitle: "Start Quick Session",
                        iconName: "shuffle",
                        isPrimary: false
                    ) {
                        startExam(.quick18m)
                    }

                    if !completedSessions.isEmpty {
                        Text("PAST ATTEMPTS")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(palette.textSecondary)
                            .padding(.top, 6)

                        ForEach(completedSessions.prefix(8)) { session in
                            NavigationLink(value: ReviewDestination.pastAttempt(session.toDTO())) {
                                pastAttemptRowLabel(session)
                            }
                            .buttonStyle(TactileCardButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    Haptics.impact(.medium)
                                    deleteSession(session)
                                } label: {
                                    Label("Delete Attempt", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Text("ALL PASSAGES")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(palette.textSecondary)
                        .padding(.top, 6)

                    ForEach(contentStore.uniquePassages) { passage in
                        NavigationLink(value: ReviewDestination.passage(passage)) {
                            passageSummaryRow(passage)
                        }
                        .buttonStyle(TactileCardButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .background(palette.bgApp)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ReviewDestination.self) { destination in
                switch destination {
                case let .passage(passage):
                    PassageReaderView(passage: passage)
                case let .pastAttempt(session):
                    PastAttemptReviewView(
                        session: session,
                        passages: contentStore.mockPassages
                    )
                }
            }
        }
        .onAppear {
            isAtRoot = navPath.isEmpty && activeCover == nil
        }
        .onChange(of: navPath) { oldPath, newPath in
            if oldPath != newPath {
                navHapticTrigger += 1
            }
            isAtRoot = newPath.isEmpty && activeCover == nil
        }
        .onChange(of: activeCover != nil) { _, hasCover in
            isAtRoot = navPath.isEmpty && !hasCover
        }
        .onChange(of: resetToRootTrigger) { _, _ in
            if !navPath.isEmpty {
                navPath.removeAll()
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: navHapticTrigger)
        .fullScreenCover(item: $activeCover) { route in
            MockSessionCoverContainer(
                initialRoute: route,
                passages: contentStore.mockPassages,
                onDismiss: { activeCover = nil }
            )
            .environment(\.lnatPalette, palette)
        }
    }

    // MARK: - Rows

    private func launchCard(
        title: String,
        subtitle: String,
        detail: String? = nil,
        buttonTitle: String,
        iconName: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(palette.textPrimary)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)

            if let detail {
                Text(detail)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 2)
            }

            Button {
                Haptics.impact(.medium)
                action()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isPrimary ? palette.accentPrimaryFg : palette.accentSecondaryText)
                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isPrimary ? palette.accentPrimaryFg : palette.textPrimary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isPrimary ? palette.accentPrimary : palette.bgMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isPrimary ? Color.clear : palette.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(16)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
    }

    private func pastAttemptRowLabel(_ session: MockSessionRecord) -> some View {
        let score = session.score ?? 0
        let total = max(1, session.totalQuestions)
        let pct = Int(((Double(score) / Double(total)) * 100.0).rounded(.toNearestOrAwayFromZero))
        let dateLabel: String = {
            guard let ms = session.completedAtMs else { return "Saved" }
            let date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
            return date.formatted(.dateTime.month(.abbreviated).day())
        }()

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.sessionTitle)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text("\(score)/\(total) correct · \(dateLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            Text("\(pct)%")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(pct >= 75 ? palette.statusCorrectText : palette.accentSecondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(pct >= 75 ? palette.statusCorrectBg : palette.bgSoftAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(pct >= 75 ? palette.statusCorrectBorder : palette.borderSubtle, lineWidth: 1)
                )

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func passageSummaryRow(_ passage: MockPassage) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(passage.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.leading)
                Text("\(passage.category) · \(passage.wordCount) words · \(passage.questions.count) questions")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textSecondary.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions

    private func startExam(_ mode: MockExamMode) {
        let built = ExamBuilder.build(passages: contentStore.mockPassages, mode: mode)
        activeCover = .exam(built)
    }

    private func deleteSession(_ session: MockSessionRecord) {
        modelContext.delete(session)
        try? modelContext.save()
    }
}
