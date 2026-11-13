//
//  UsageSummary.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 13/11/2026.
//

/// The per-item cells and footer lines shared by the text report and the Obsidian note.
enum UsageSummary {
    /// Column titles of the text report, in cell order (after the tool name).
    static let textHeaders = ["Uses", "%sess", "units/use", "ctx carry", "%ctx", "~5h pp", "~7d pp", "USD"]

    /// Column titles of the Obsidian note, in cell order (after the tool name).
    static let noteHeaders = ["Uses", "% sess", "Units/use", "Ctx carry", "% ctx", "~5h pp", "~7d pp", "Est. cost"]

    /// Cells for `item`, in header order. Unknown values are `—` (`n/a` for cost). The uses cell is
    /// `<usesPrefix><uses>`, plus ` (<k> sub)` when `k` uses were inside subagents.
    static func cells(_ item: ReportItem, usesPrefix: String) -> [String] {
        let count = "\(usesPrefix)\(item.uses)"
        let uses = item.usesInSubagents > 0 ? "\(count) (\(item.usesInSubagents) sub)" : count
        return [uses,
                UsageFormat.share(item.sessionShare),
                UsageFormat.units(item.weightedPerUse),
                UsageFormat.units(item.contextCarry),
                item.liveContextShare.map(UsageFormat.share(_:)) ?? "—",
                points(item.windowPoints?.fiveHour),
                points(item.windowPoints?.sevenDay),
                item.estimatedCostUSD.map(UsageFormat.cost(_:)) ?? "n/a"]
    }

    /// `Session 23.8k units (price-weighted tokens), 84% attributed to tools`.
    static func sessionLine(_ report: SessionReport) -> String {
        let attributed = report.sessionWeighted > 0 ? report.attributedWeighted / report.sessionWeighted : 0
        return "Session \(UsageFormat.units(report.sessionWeighted)) units (price-weighted tokens), "
            + "\(UsageFormat.share(attributed)) attributed to tools"
    }

    /// The session's window use, or `nil` without a baseline.
    static func windowLine(_ report: SessionReport) -> String? {
        report.windowDelta.map { delta in
            "Window use this session: 5h \(signed(delta.fiveHour)) · 7d \(signed(delta.sevenDay)) "
                + "(estimate: includes parallel sessions; weighting is a price proxy)"
        }
    }

    /// `Attributed $0.17 of session $0.20 (estimate, source: costState)`.
    static func costLine(_ report: SessionReport) -> String {
        "Attributed \(cost(report.attributedCostUSD)) of session \(cost(report.sessionCostUSD)) "
            + "(estimate, source: \(report.costSource.rawValue))"
    }

    // MARK: - Private

    private static func points(_ value: Double?) -> String {
        value.map(UsageFormat.points(_:)) ?? "—"
    }

    private static func signed(_ value: Double?) -> String {
        value.map { "+\(UsageFormat.points($0)) pp" } ?? "—"
    }

    private static func cost(_ usd: Double?) -> String {
        usd.map(UsageFormat.cost(_:)) ?? "n/a"
    }
}
