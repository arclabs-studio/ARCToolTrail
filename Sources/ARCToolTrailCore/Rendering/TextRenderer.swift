//
//  TextRenderer.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Multi-line plain-text report: one section per non-empty category (`ToolCategory.title`), one row
/// per item (`name`, uses, cost), then the session and attributed totals and the cleanup list.
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
            let width = items.map(\.identity.name.count).max() ?? 0
            for item in items {
                let name = item.identity.name.padding(toLength: width, withPad: " ", startingAt: 0)
                let inSubagents = item.usesInSubagents > 0 ? " (\(item.usesInSubagents) in subagents)" : ""
                lines.append("  \(name)  ×\(item.uses)\(inSubagents)  \(cost(item.estimatedCostUSD))")
            }
        }
        lines.append("")
        lines.append("Attributed \(cost(report.attributedCostUSD)) of session \(cost(report.sessionCostUSD)) "
            + "(estimate, source: \(report.costSource.rawValue))")
        if !report.cleanup.isEmpty {
            lines.append("")
            lines.append("Loaded, never used:")
            lines
                .append(contentsOf: report.cleanup
                    .map { "  \($0.kind == .mcpServer ? "server" : "plugin") \($0.name)" })
        }
        return lines.joined(separator: "\n")
    }

    private static func cost(_ usd: Double?) -> String {
        usd.map(StatuslineRenderer.formatCost(_:)) ?? "n/a"
    }
}
