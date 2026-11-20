import SwiftUI

public struct PassageReaderView: View {
    @Environment(\.lnatPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    public let passage: MockPassage

    public init(passage: MockPassage) {
        self.passage = passage
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    editorialHeader

                    Divider()
                        .overlay(palette.borderSubtle)

                    let blocks = passage.paragraphs.isEmpty ? [passage.passage] : passage.paragraphs
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { _, para in
                            FormattedBlockView(
                                text: para,
                                font: .system(size: 17, design: .serif),
                                lineSpacing: 8,
                                tableFontSize: 13
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bgApp)
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractivePopGesture()
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Passages")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(palette.accentPrimary)
                .frame(minHeight: 44)
                .padding(.trailing, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Passage")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(palette.bgSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.borderSubtle).frame(height: 1)
        }
    }

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(passage.category)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(palette.accentSecondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.bgSoftAccent)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(palette.borderSubtle, lineWidth: 1)
                    )

                Text("\(passage.wordCount) words")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }

            Text(passage.title)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
