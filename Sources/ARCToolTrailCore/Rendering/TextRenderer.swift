//
//  TextRenderer.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Multi-line plain-text report: one section per non-empty category (`ToolCategory.title`) with a
/// header row and one aligned row per item (`Tool  Uses  %sess  units/use  ctx carry  %ctx  ~5h pp
/// ~7d pp  USD`), then the session line, the window line (with a baseline), the USD totals and the
/// cleanup list.
public enum TextRenderer {
    public static func render(_ report: SessionReport) -> String {
        var lines = ["Session \(report.sessionId)"]
        for category in ToolCategory.allCases {
            let items = report.items(in: category)
            guard !items.isEmpty else {
                continue
            }
            lines.append("")
            lines.append(category.title)
            let rows = [["Tool"] + UsageSummary.textHeaders]
                + items.map { [$0.identity.name] + UsageSummary.cells($0, usesPrefix: "×") }
            lines.append(contentsOf: align(rows))
        }
        lines.append("")
        lines.append(UsageSummary.sessionLine(report))
        if let window = UsageSummary.windowLine(report) {
            lines.append(window)
        }
        lines.append(UsageSummary.costLine(report))
        if !report.cleanup.isEmpty {
            lines.append("")
            lines.append("Loaded, never used:")
            lines
                .append(contentsOf: report.cleanup
                    .map { "  \($0.kind == .mcpServer ? "server" : "plugin") \($0.name)" })
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    /// First column left-aligned, the rest right-aligned, two spaces apart, indented by two.
    private static func align(_ rows: [[String]]) -> [String] {
        let columns = rows.first?.count ?? 0
        let widths = (0 ..< columns).map { column in rows.map { $0[column].count }.max() ?? 0 }
        return rows.map { row in
            let cells = row.indices.map { column in
                let pad = String(repeating: " ", count: widths[column] - row[column].count)
                return column == 0 ? row[column] + pad : pad + row[column]
            }
            return "  " + cells.joined(separator: "  ")
        }
    }
}
