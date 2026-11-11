//
//  MarkdownNoteRenderer.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Obsidian note: YAML front matter (`type: claude-session-tools`, `session`, `date`,
/// `tags: [claude-code, tooltrail]`), then one Markdown table per non-empty category with columns
/// `Tool | Uses | Est. cost`, the totals, and a `## Cleanup suggestions` section when there are any.
public enum MarkdownNoteRenderer {
    public static func render(_ report: SessionReport) -> String {
        var lines = ["---",
                     "type: claude-session-tools",
                     "session: \(report.sessionId)",
                     "date: \(report.generatedAt.formatted(.iso8601))",
                     "tags: [claude-code, tooltrail]",
                     "---",
                     "",
                     "# Session tools \(report.sessionId.prefix(8))"]
        for category in ToolCategory.allCases {
            let items = report.items(in: category)
            guard !items.isEmpty else {
                continue
            }
            lines.append(contentsOf: ["", "## \(category.title)", "", "| Tool | Uses | Est. cost |",
                                      "| --- | ---: | ---: |"])
            lines
                .append(contentsOf: items.map { "| \($0.identity.name) | \($0.uses) | \(cost($0.estimatedCostUSD)) |" })
        }
        lines.append(contentsOf: ["",
                                  "Attributed \(cost(report.attributedCostUSD)) "
                                      + "of session \(cost(report.sessionCostUSD)) "
                                      + "(estimate, source: `\(report.costSource.rawValue)`)."])
        if !report.cleanup.isEmpty {
            lines.append(contentsOf: ["", "## Cleanup suggestions", ""])
            lines
                .append(contentsOf: report.cleanup
                    .map { "- \($0.kind == .mcpServer ? "MCP server" : "plugin") `\($0.name)`" })
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func cost(_ usd: Double?) -> String {
        usd.map(StatuslineRenderer.formatCost(_:)) ?? "n/a"
    }
}
