import SwiftData
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var attempts: [QuestionAttempt]
    @Query private var mockSessions: [MockSessionRecord]
    @Query private var outlines: [SavedOutline]
    @Query private var completedCards: [CompletedCardRecord]

    @Binding public var themeModeRaw: String
    public let questionsCount: Int
    public let completedCardsCount: Int
    public let mockSessionsCount: Int
    public let outlinesCount: Int

    @State private var isImporterPresented = false
    @State private var confirmReset = false
    @State private var feedback: (isError: Bool, message: String)?
    @State private var importSuccessTrigger = 0
    @State private var importErrorTrigger = 0

    private var themeMode: ThemeMode {
        ThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var resolvedScheme: ColorScheme {
        themeMode.resolvedColorScheme(system: colorScheme)
    }

    private var palette: LNATPalette {
        LNATPalette.resolve(for: resolvedScheme)
    }

    private var backupDocument: LNATBackupDocument {
        (try? BackupService.makeBackupDocument(
            attempts: attempts,
            mockSessions: mockSessions,
            outlines: outlines,
            completedCards: completedCards
        )) ?? LNATBackupDocument(filename: "lnat-forge-backup.json", jsonData: Data("{}".utf8))
    }

    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Appearance, backups, and study data.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.textSecondary)

                    appearanceCard
                    summaryGrid

                    if let feedback {
                        HStack(spacing: 8) {
                            Image(systemName: feedback.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text(feedback.message)
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .foregroundStyle(feedback.isError ? palette.statusTrapText : palette.statusCorrectText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(feedback.isError ? palette.statusTrapBg : palette.statusCorrectBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(feedback.isError ? palette.statusTrapBorder : palette.statusCorrectBorder, lineWidth: 1)
                        )
                    }

                    actionsSection
                }
                .padding(16)
            }
            .background(palette.bgSurface)
            .navigationTitle("Settings")
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
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
        }
        .environment(\.colorScheme, resolvedScheme)
        .sensoryFeedback(.selection, trigger: themeModeRaw)
        .sensoryFeedback(.success, trigger: importSuccessTrigger)
        .sensoryFeedback(.error, trigger: importErrorTrigger)
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.accentSecondaryText)
                    Text("Appearance")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                }

                Spacer()

                Text(themeMode.statusLabel(resolvedScheme: resolvedScheme))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }

            HStack(spacing: 6) {
                ForEach(ThemeMode.allCases) { mode in
                    let isSelected = themeMode == mode
                    Button {
                        themeModeRaw = mode.rawValue
                        mode.applyWindowInterfaceStyle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 12))
                            Text(mode.label)
                                .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                        }
                        .foregroundStyle(isSelected ? palette.accentPrimaryFg : palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(isSelected ? palette.accentPrimary : palette.bgSurface)
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
        .padding(12)
        .background(palette.bgMuted)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))
    }

    private var summaryGrid: some View {
        HStack(spacing: 8) {
            summaryTile(value: "\(questionsCount)", label: "Questions", color: palette.textPrimary)
            summaryTile(value: "\(completedCardsCount)", label: "Cards", color: palette.accentSecondaryText)
            summaryTile(value: "\(mockSessionsCount)", label: "Papers", color: palette.accentBlueText)
            summaryTile(value: "\(outlinesCount)", label: "Outlines", color: palette.textPrimary)
        }
    }

    private func summaryTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(palette.bgMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            let doc = backupDocument
            ShareLink(
                item: doc,
                preview: SharePreview(doc.filename, image: Image(systemName: "doc.text"))
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Export Backup")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(palette.accentPrimaryFg)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(palette.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                Haptics.impact(.light)
                isImporterPresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.accentSecondaryText)
                    Text("Import Backup")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(palette.bgMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if confirmReset {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reset all study history? This removes your answered questions, past attempts, and saved outlines.")
                        .font(.system(size: 12, weight: .medium))
                        .lineSpacing(3)
                        .foregroundStyle(palette.statusTrapText)

                    HStack(spacing: 8) {
                        Button {
                            confirmReset = false
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(palette.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(palette.bgSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.borderSubtle, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button {
                            resetHistory()
                        } label: {
                            Text("Confirm Reset")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Color(hex: 0xE11D48))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(palette.statusTrapBg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.statusTrapBorder, lineWidth: 1))
            } else {
                Button {
                    Haptics.warning()
                    confirmReset = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Reset Study History")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(palette.statusTrapText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(palette.statusTrapBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(palette.statusTrapBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .failure(error):
            feedback = (true, error.localizedDescription)
        case let .success(urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                let summary = try BackupService.importJSON(data, into: modelContext)
                importSuccessTrigger += 1
                feedback = (
                    false,
                    "Restored \(summary.telemetryImported) answers, \(summary.mockSessionsImported) tests, and \(summary.outlinesImported) outlines."
                )
            } catch {
                importErrorTrigger += 1
                feedback = (true, error.localizedDescription)
            }
        }
    }

    private func resetHistory() {
        do {
            try BackupService.resetAllStudyHistory(in: modelContext)
            Haptics.impact(.medium)
            confirmReset = false
            feedback = (false, "All study history has been reset.")
        } catch {
            Haptics.warning()
            feedback = (true, "Unable to reset study history.")
        }
    }
}
