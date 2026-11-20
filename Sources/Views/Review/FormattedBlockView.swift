import SwiftUI

public enum FormattedSegment: Equatable, Sendable {
    case text(String)
    case table(headers: [String], rows: [[String]])
}

public enum FormattedBlockParser {
    public static func parse(_ raw: String) -> [FormattedSegment] {
        let lines = raw.components(separatedBy: "\n")
        var segments: [FormattedSegment] = []
        var textBuffer: [String] = []
        var index = 0

        func flushText() {
            let joined = textBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                segments.append(.text(joined))
            }
            textBuffer.removeAll()
        }

        while index < lines.count {
            let line = lines[index]
            let nextLine = index + 1 < lines.count ? lines[index + 1] : nil

            if line.trimmingCharacters(in: .whitespaces).hasPrefix("|"),
               let sepLine = nextLine,
               isSeparatorLine(sepLine) {
                flushText()
                let headers = parsePipeRow(line)
                index += 2
                var rows: [[String]] = []
                while index < lines.count,
                      lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    rows.append(parsePipeRow(lines[index]))
                    index += 1
                }
                segments.append(.table(headers: headers, rows: rows))
                continue
            }

            textBuffer.append(line)
            index += 1
        }

        flushText()
        return segments
    }

    private static func parsePipeRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private static func isSeparatorLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        let cells = parsePipeRow(trimmed)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            cell.range(of: #"^:?-{2,}:?$"#, options: .regularExpression) != nil
        }
    }
}

public struct FormattedBlockView: View {
    @Environment(\.lnatPalette) private var palette

    public let text: String
    public let font: Font
    public let lineSpacing: CGFloat
    public let textColor: Color?
    public let tableFontSize: CGFloat

    public init(
        text: String,
        font: Font = .system(size: 16, design: .serif),
        lineSpacing: CGFloat = 6,
        textColor: Color? = nil,
        tableFontSize: CGFloat = 11
    ) {
        self.text = text
        self.font = font
        self.lineSpacing = lineSpacing
        self.textColor = textColor
        self.tableFontSize = tableFontSize
    }

    public var body: some View {
        let segments = FormattedBlockParser.parse(text)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case let .text(content):
                    Text(content)
                        .font(font)
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(textColor ?? palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                case let .table(headers, rows):
                    markdownTableView(headers: headers, rows: rows)
                }
            }
        }
    }

    private func markdownTableView(headers: [String], rows: [[String]]) -> some View {
        let isEditorial = tableFontSize >= 12
        let columnCount = max(headers.count, rows.map(\.count).max() ?? 0)
        let firstColWidth: CGFloat = isEditorial ? 132 : 108
        let otherColWidth: CGFloat = isEditorial ? 172 : 144
        let hPad: CGFloat = isEditorial ? 12 : 9
        let vPad: CGFloat = isEditorial ? 10 : 7

        return ScrollView(.horizontal, showsIndicators: isEditorial) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<columnCount, id: \.self) { colIdx in
                        let header = colIdx < headers.count ? headers[colIdx] : ""
                        let colWidth = colIdx == 0 ? firstColWidth : otherColWidth

                        Text(header)
                            .font(.system(size: tableFontSize, weight: .bold))
                            .lineSpacing(3)
                            .foregroundStyle(palette.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, hPad)
                            .padding(.vertical, vPad)
                            .frame(width: colWidth, alignment: .topLeading)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                            .background(palette.bgSoftAccent.opacity(0.65))
                            .clipped()
                            .overlay(alignment: .trailing) {
                                if colIdx < columnCount - 1 {
                                    Rectangle().fill(palette.borderSubtle).frame(width: 1)
                                }
                            }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(palette.borderSubtle).frame(height: 1)
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                    let isEvenRow = rowIdx % 2 == 1
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(0..<columnCount, id: \.self) { colIdx in
                            let cell = colIdx < row.count ? row[colIdx] : ""
                            let colWidth = colIdx == 0 ? firstColWidth : otherColWidth

                            Text(cell)
                                .font(.system(size: tableFontSize, weight: colIdx == 0 ? .semibold : .regular))
                                .lineSpacing(3)
                                .foregroundStyle(palette.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, hPad)
                                .padding(.vertical, vPad)
                                .frame(width: colWidth, alignment: .topLeading)
                                .frame(maxHeight: .infinity, alignment: .topLeading)
                                .background(
                                    colIdx == 0
                                        ? palette.bgMuted.opacity(0.85)
                                        : (isEvenRow ? palette.bgMuted.opacity(0.5) : palette.bgSurface)
                                )
                                .clipped()
                                .overlay(alignment: .trailing) {
                                    if colIdx < columnCount - 1 {
                                        Rectangle().fill(palette.borderSubtle).frame(width: 1)
                                    }
                                }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay(alignment: .bottom) {
                        if rowIdx < rows.count - 1 {
                            Rectangle().fill(palette.borderSubtle).frame(height: 1)
                        }
                    }
                }
            }
            .background(palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(palette.borderSubtle, lineWidth: 1)
            )
            .padding(.bottom, isEditorial ? 10 : 0)
        }
    }
}
