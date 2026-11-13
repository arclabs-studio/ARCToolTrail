//
//  MarkdownNoteRenderer.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Obsidian note: YAML front matter (`type: claude-session-tools`, `session`, `date`,
/// `session_weighted`, `window_5h_pp` / `window_7d_pp` when known, `tags: [claude-code, tooltrail]`),
/// then one Markdown table per non-empty category with columns
/// `Tool | Uses | % sess | Units/use | Ctx carry | % ctx | ~5h pp | ~7d pp | Est. cost`, the totals,
/// and a `## Cleanup suggestions` section when there are any.
public enum MarkdownNoteRenderer {
    public static func render(_ report: SessionReport) -> String {
        var lines = ["---",
                     "type: claude-session-tools",
                     "session: \(report.sessionId)",
                     "date: \(report.generatedAt.formatted(.iso8601))",
                     "session_weighted: \(Int(report.sessionWeighted.rounded()))"]
        if let fiveHour = report.windowDelta?.fiveHour {
            lines.append("window_5h_pp: \(twoDecimals(fiveHour))")
        }
        if let sevenDay = report.windowDelta?.sevenDay {
            lines.append("window_7d_pp: \(twoDecimals(sevenDay))")
        }
        lines.append(contentsOf: ["tags: [claude-code, tooltrail]",
                                  "---",
                                  "",
                                  "# Session tools \(report.sessionId.prefix(8))"])
        let headers = ["Tool"] + UsageSummary.noteHeaders
        let rule = ["---"] + Array(repeating: "---:", count: UsageSummary.noteHeaders.count)
        for category in ToolCategory.allCases {
            let items = report.items(in: category)
            guard !items.isEmpty else {
                continue
            }
            lines.append(contentsOf: ["", "## \(category.title)", "", row(headers), row(rule)])
            lines.append(contentsOf: items.map { row([$0.identity.name] + UsageSummary.cells($0, usesPrefix: "")) })
        }
        lines.append("")
        lines.append(UsageSummary.sessionLine(report) + ".")
        if let window = UsageSummary.windowLine(report) {
            lines.append(window + ".")
        }
        lines.append("Attributed \(cost(report.attributedCostUSD)) "
            + "of session \(cost(report.sessionCostUSD)) "
            + "(estimate, source: `\(report.costSource.rawValue)`).")
        if !report.cleanup.isEmpty {
            lines.append(contentsOf: ["", "## Cleanup suggestions", ""])
            lines
                .append(contentsOf: report.cleanup
                    .map { "- \($0.kind == .mcpServer ? "MCP server" : "plugin") `\($0.name)`" })
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    private static func row(_ cells: [String]) -> String {
        "| " + cells.joined(separator: " | ") + " |"
    }

    private static func cost(_ usd: Double?) -> String {
        usd.map(UsageFormat.cost(_:)) ?? "n/a"
    }

    private static func twoDecimals(_ value: Double) -> String {
        value.formatted(FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(2))
            .grouping(.never)
            .locale(Locale(identifier: "en_US_POSIX")))
    }
}
