import Combine
import SwiftData
import SwiftUI

public struct EssaysTabView: View {
    @Environment(\.lnatPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedOutline.updatedAtMs, order: .reverse) private var outlines: [SavedOutline]

    public enum SubView: String, CaseIterable {
        case composer = "New Outline"
        case history = "Saved Outlines"
    }

    public let contentStore: ContentStore

    @State private var subView: SubView = .composer
    @State private var selectedCategory: String = "All"
    @State private var promptIdx = 0
    @State private var secondsLeft = 300
    @State private var isRunning = false
    @State private var showKeyTension = false

    @State private var editingOutlineId: String?
    @State private var thesis = ""
    @State private var point1 = ""
    @State private var point2 = ""
    @State private var counterargument = ""
    @State private var rebuttal = ""
    @State private var savedFlag = false
    @State private var outlineSavedTrigger = 0

    private let sprintDurationSeconds = 300
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(contentStore: ContentStore = .shared) {
        self.contentStore = contentStore
    }

    private var categoryOptions: [String] {
        ["All"] + contentStore.sectionBCategories
    }

    private var filteredPrompts: [SectionBPrompt] {
        let all = contentStore.sectionBPrompts
        guard selectedCategory != "All" else { return all }
        let matching = all.filter { $0.category == selectedCategory }
        return matching.isEmpty ? all : matching
    }

    private var activePrompt: SectionBPrompt? {
        let pool = filteredPrompts
        guard !pool.isEmpty else { return nil }
        return pool[min(promptIdx, pool.count - 1)]
    }

    private var canSave: Bool {
        !thesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !point1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !point2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !counterargument.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !rebuttal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var formattedTimer: String {
        let mm = secondsLeft / 60
        let ss = secondsLeft % 60
        return String(format: "%02d:%02d", mm, ss)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topHeader
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)

            subTabSwitcher
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            if subView == .composer {
                composerView
            } else {
                savedOutlinesView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bgApp)
        .onReceive(ticker) { _ in
            guard isRunning else { return }
            if secondsLeft <= 1 {
                secondsLeft = 0
                isRunning = false
                Haptics.warning()
            } else {
                secondsLeft -= 1
            }
        }
        .sensoryFeedback(.selection, trigger: selectedCategory)
        .sensoryFeedback(.selection, trigger: subView)
        .sensoryFeedback(.success, trigger: outlineSavedTrigger)
    }

    // MARK: - Top Header & Switcher

    private var topHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Essay Outlines")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Text("\(outlines.count) saved outline\(outlines.count == 1 ? "" : "s")")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

            HStack(spacing: 6) {
                let isUrgent = secondsLeft <= 30 && isRunning
                Text(formattedTimer)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(isUrgent ? palette.statusTrapText : palette.accentPrimary)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 36)
                    .background(isUrgent ? palette.statusTrapBg : palette.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isUrgent ? palette.statusTrapBorder : palette.borderSubtle, lineWidth: 1)
                    )

                Button {
                    Haptics.impact(.light)
                    isRunning.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(palette.accentPrimaryFg)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 36)
                    .background(palette.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.impact(.light)
                    isRunning = false
                    secondsLeft = sprintDurationSeconds
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(palette.bgSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(palette.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset timer")
            }
        }
    }

    private var subTabSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(SubView.allCases, id: \.self) { tab in
                let isSelected = subView == tab
                Button {
                    subView = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab == .composer ? "pencil.line" : "clock.arrow.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                    }
                    .foregroundStyle(isSelected ? palette.accentPrimaryFg : palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(isSelected ? palette.accentPrimary : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Composer View

    private var composerView: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    categoryFilterBar

                    if let prompt = activePrompt {
                        promptCard(prompt)
                    }

                    VStack(spacing: 12) {
                        outlineField(
                            title: "Thesis",
                            placeholder: "Your central position and key distinction...",
                            text: $thesis
                        )
                        outlineField(
                            title: "First Argument",
                            placeholder: "Main supporting principle and real-world example...",
                            text: $point1
                        )
                        outlineField(
                            title: "Second Argument",
                            placeholder: "Independent second point or policy consequence...",
                            text: $point2
                        )
                        outlineField(
                            title: "Counterargument",
                            placeholder: "Strongest objection to your thesis...",
                            text: $counterargument
                        )
                        outlineField(
                            title: "Conclusion",
                            placeholder: "Why your thesis holds despite the objection...",
                            text: $rebuttal
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            HStack(spacing: 10) {
                if canSave {
                    Button {
                        Haptics.impact(.light)
                        clearFields()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(palette.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(palette.borderSubtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    saveCurrentOutline()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: savedFlag ? "checkmark" : "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                        Text(
                            savedFlag
                                ? "Outline Saved"
                                : (editingOutlineId != nil ? "Update Outline" : "Save Outline")
                        )
                        .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(palette.accentPrimaryFg)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(palette.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(canSave ? 1.0 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(palette.bgApp)
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categoryOptions, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        selectedCategory = category
                        promptIdx = 0
                        editingOutlineId = nil
                        showKeyTension = false
                    } label: {
                        Text(category)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(isSelected ? palette.accentPrimaryFg : palette.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? palette.accentPrimary : palette.bgSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? palette.accentPrimary : palette.borderSubtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func promptCard(_ prompt: SectionBPrompt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(prompt.category)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accentSecondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(palette.bgSoftAccent)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(palette.borderSubtle, lineWidth: 1))

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        Haptics.impact(.light)
                        shufflePrompt()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 11))
                            Text("Shuffle")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(palette.accentSecondaryText)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 32)
                        .background(palette.bgMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(palette.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.impact(.light)
                        nextPrompt()
                    } label: {
                        Text("Next →")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.accentPrimary)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(prompt.prompt)
                .font(.system(size: 15, design: .serif))
                .lineSpacing(5)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(palette.borderSubtle.opacity(0.7))
                    .frame(height: 1)

                Button {
                    Haptics.impact(.light)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showKeyTension.toggle()
                    }
                } label: {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                            Text(showKeyTension ? "Hide Essay Angle" : "Show Essay Angle")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Spacer()
                        Image(systemName: showKeyTension ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(palette.accentBlueText)
                    .frame(minHeight: 30)
                }
                .buttonStyle(.plain)

                if showKeyTension {
                    Text(prompt.keyTension)
                        .font(.system(size: 12.5))
                        .lineSpacing(3.5)
                        .foregroundStyle(palette.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.bgMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(palette.borderSubtle, lineWidth: 1)
                        )
                }
            }
        }
        .padding(14)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
    }

    private func outlineField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textSecondary)

            TextField(placeholder, text: text, axis: .vertical)
                .font(.system(size: 13.5))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(palette.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.borderSubtle, lineWidth: 1)
                )
        }
    }

    // MARK: - Saved Outlines History

    private var savedOutlinesView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                if outlines.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 24))
                            .foregroundStyle(palette.textSecondary)
                        Text("No saved outlines yet")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Draft an essay structure in New Outline to review and refine it here.")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(palette.bgSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(palette.borderSubtle, lineWidth: 1)
                    )
                    .padding(.top, 6)
                } else {
                    ForEach(outlines) { item in
                        savedOutlineCard(item)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
    }

    private func savedOutlineCard(_ item: SavedOutline) -> some View {
        let dateLabel = Date(timeIntervalSince1970: Double(item.updatedAtMs) / 1000.0)
            .formatted(.dateTime.month(.abbreviated).day())

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("“\(item.promptText)”")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(palette.textPrimary)
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.accentSecondaryText)
                    Text("\(item.durationSeconds)s · \(dateLabel)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }
            }

            VStack(spacing: 8) {
                if !item.thesis.isEmpty {
                    savedSectionRow(label: "THESIS", text: item.thesis, labelColor: palette.accentPrimary)
                }
                if !item.point1.isEmpty {
                    savedSectionRow(label: "FIRST ARGUMENT", text: item.point1, labelColor: palette.statusCorrectText)
                }
                if !item.point2.isEmpty {
                    savedSectionRow(label: "SECOND ARGUMENT", text: item.point2, labelColor: palette.statusCorrectText)
                }
                if !item.counterargument.isEmpty {
                    savedSectionRow(label: "COUNTERARGUMENT", text: item.counterargument, labelColor: palette.statusTrapText)
                }
                if !item.rebuttal.isEmpty {
                    savedSectionRow(label: "CONCLUSION", text: item.rebuttal, labelColor: palette.accentBlueText)
                }
            }

            HStack {
                Spacer()
                Button {
                    Haptics.impact(.medium)
                    modelContext.delete(item)
                    try? modelContext.save()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("Delete")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(palette.statusTrapText)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 38)
                    .background(palette.statusTrapBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(palette.statusTrapBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.impact(.light)
                    loadOutline(item)
                } label: {
                    Text("Edit Outline")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.accentPrimaryFg)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 38)
                        .background(palette.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(palette.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
    }

    private func savedSectionRow(label: String, text: String, labelColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(labelColor)
            Text(text)
                .font(.system(size: 12.5))
                .lineSpacing(3)
                .foregroundStyle(palette.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func shufflePrompt() {
        let pool = filteredPrompts
        guard pool.count > 1 else { return }
        var next = promptIdx
        while next == promptIdx {
            next = Int.random(in: 0..<pool.count)
        }
        promptIdx = next
        editingOutlineId = nil
        showKeyTension = false
    }

    private func nextPrompt() {
        let pool = filteredPrompts
        guard !pool.isEmpty else { return }
        promptIdx = (promptIdx + 1) % pool.count
        editingOutlineId = nil
        showKeyTension = false
    }

    private func clearFields() {
        editingOutlineId = nil
        thesis = ""
        point1 = ""
        point2 = ""
        counterargument = ""
        rebuttal = ""
    }

    private func saveCurrentOutline() {
        guard canSave, let prompt = activePrompt else { return }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let trimmedThesis = thesis.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPoint1 = point1.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPoint2 = point2.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCounter = counterargument.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRebuttal = rebuttal.trimmingCharacters(in: .whitespacesAndNewlines)
        let elapsedSeconds = max(0, sprintDurationSeconds - secondsLeft)

        if let editingId = editingOutlineId,
           let existing = outlines.first(where: { $0.id == editingId }) {
            existing.promptId = prompt.id
            existing.promptText = prompt.prompt
            existing.thesis = trimmedThesis
            existing.point1 = trimmedPoint1
            existing.point2 = trimmedPoint2
            existing.counterargument = trimmedCounter
            existing.rebuttal = trimmedRebuttal
            existing.durationSeconds = elapsedSeconds
            existing.updatedAtMs = nowMs
        } else {
            let outline = SavedOutline(
                promptId: prompt.id,
                promptText: prompt.prompt,
                thesis: trimmedThesis,
                point1: trimmedPoint1,
                point2: trimmedPoint2,
                counterargument: trimmedCounter,
                rebuttal: trimmedRebuttal,
                durationSeconds: elapsedSeconds,
                createdAtMs: nowMs,
                updatedAtMs: nowMs
            )
            modelContext.insert(outline)
            editingOutlineId = outline.id
        }

        try? modelContext.save()
        isRunning = false
        outlineSavedTrigger += 1
        savedFlag = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            savedFlag = false
        }
    }

    private func loadOutline(_ outline: SavedOutline) {
        selectedCategory = "All"
        if let matchedIdx = contentStore.sectionBPrompts.firstIndex(where: { $0.id == outline.promptId }) {
            promptIdx = matchedIdx
        } else {
            promptIdx = 0
        }
        editingOutlineId = outline.id
        thesis = outline.thesis
        point1 = outline.point1
        point2 = outline.point2
        counterargument = outline.counterargument
        rebuttal = outline.rebuttal
        subView = .composer
    }
}
