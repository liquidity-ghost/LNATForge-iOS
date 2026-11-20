import SwiftUI

public struct QuestionGridSheet: View {
    @Environment(\.lnatPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    public enum Filter: String, CaseIterable {
        case all
        case unanswered
        case flagged
    }

    public let items: [ExamQuestionItem]
    public let activeIndex: Int
    public let answers: [String: Int]
    public let flaggedIds: Set<String>
    public let onSelectQuestion: (Int) -> Void
    public let onSubmitExam: () -> Void

    @State private var filter: Filter = .all

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    private var answeredCount: Int {
        items.filter { answers[$0.question.id] != nil }.count
    }

    private var unansweredCount: Int {
        items.count - answeredCount
    }

    private var flaggedCount: Int {
        items.filter { flaggedIds.contains($0.question.id) }.count
    }

    private var filteredItems: [ExamQuestionItem] {
        switch filter {
        case .all:
            return items
        case .unanswered:
            return items.filter { answers[$0.question.id] == nil }
        case .flagged:
            return items.filter { flaggedIds.contains($0.question.id) }
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    counterTile(
                        label: "Answered",
                        count: answeredCount,
                        bg: palette.statusCorrectBg,
                        border: palette.statusCorrectBorder,
                        text: palette.statusCorrectText
                    )
                    counterTile(
                        label: "Remaining",
                        count: unansweredCount,
                        bg: palette.bgSurface,
                        border: palette.borderSubtle,
                        text: palette.textSecondary,
                        countColor: palette.textPrimary
                    )
                    counterTile(
                        label: "Flagged",
                        count: flaggedCount,
                        bg: palette.bgSoftAccent,
                        border: palette.accentSecondary.opacity(0.6),
                        text: palette.accentSecondaryText
                    )
                }

                HStack(spacing: 4) {
                    filterButton(.all, label: "All (\(items.count))")
                    filterButton(.unanswered, label: "Remaining (\(unansweredCount))")
                    filterButton(.flagged, label: "Flagged (\(flaggedCount))")
                }
                .padding(4)
                .background(palette.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.borderSubtle, lineWidth: 1)
                )

                ScrollView(.vertical, showsIndicators: false) {
                    if filteredItems.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(palette.statusCorrectSolid)
                            Text("No questions match this filter.")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 130)
                        .background(palette.bgSurface.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundStyle(palette.borderSubtle)
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(filteredItems) { item in
                                questionTile(item)
                            }
                        }
                        .padding(2)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        Haptics.impact(.light)
                        dismiss()
                    } label: {
                        Text("Resume")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .background(palette.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(palette.borderSubtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.impact(.medium)
                        dismiss()
                        onSubmitExam()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 13))
                            Text("Submit Test (\(answeredCount)/\(items.count))")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(palette.statusCorrectSolidFg)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(palette.statusCorrectSolid)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(palette.bgApp)
            .navigationTitle("Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: filter)
    }

    private func counterTile(
        label: String,
        count: Int,
        bg: Color,
        border: Color,
        text: Color,
        countColor: Color? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(text)
            Spacer()
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(countColor ?? text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
    }

    private func filterButton(_ target: Filter, label: String) -> some View {
        let isSelected = filter == target
        return Button {
            filter = target
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? palette.accentPrimaryFg : palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? palette.accentPrimary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func questionTile(_ item: ExamQuestionItem) -> some View {
        let selectedIdx = answers[item.question.id]
        let isAnswered = selectedIdx != nil
        let isFlagged = flaggedIds.contains(item.question.id)
        let isCurrent = item.globalIndex == activeIndex

        let bgColor: Color
        let borderColor: Color
        let textColor: Color
        if isAnswered {
            bgColor = palette.statusCorrectBg
            borderColor = palette.statusCorrectBorder
            textColor = palette.statusCorrectText
        } else if isFlagged {
            bgColor = palette.bgSoftAccent
            borderColor = palette.accentSecondary
            textColor = palette.accentSecondaryText
        } else {
            bgColor = palette.bgSurface
            borderColor = palette.borderSubtle
            textColor = palette.textPrimary
        }

        let letter = selectedIdx.flatMap { idx in
            idx >= 0 && idx < ExamBuilder.optionLetters.count ? ExamBuilder.optionLetters[idx] : nil
        } ?? "—"

        return Button {
            Haptics.impact(.light)
            onSelectQuestion(item.globalIndex)
            dismiss()
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 2) {
                    Text("\(item.questionNumberInExam)")
                        .font(.system(size: 12, weight: .bold))
                    Text(letter)
                        .font(.system(size: 10, design: .monospaced))
                        .opacity(0.85)
                }
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isCurrent ? palette.accentPrimary : borderColor, lineWidth: isCurrent ? 2 : 1)
                )

                if isFlagged {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.accentSecondaryText)
                        .padding(5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
