//
//  StatuslineRenderer.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// One-line summary for the Claude Code statusline.
///
/// Format: the top `limit` items by estimated cost (missing cost = 0; ties: more uses first, then
/// name), each as `<name>×<uses> <cost>`, joined by ` · `. Cost is `$0.12` (two decimals,
/// POSIX locale), `<$0.01` below one cent, and omitted when unknown. When items are left out,
/// ` · +<count>` is appended. With no items: `no tools yet`.
public enum StatuslineRenderer {
    public static func render(_ report: SessionReport, limit: Int = 4) -> String {
        guard !report.items.isEmpty else {
            return "no tools yet"
        }
        let ranked = report.items.sorted { lhs, rhs in
            let lhsCost = lhs.estimatedCostUSD ?? 0
            let rhsCost = rhs.estimatedCostUSD ?? 0
            if lhsCost != rhsCost {
                return lhsCost > rhsCost
            }
            if lhs.uses != rhs.uses {
                return lhs.uses > rhs.uses
            }
            return lhs.identity.name < rhs.identity.name
        }
        var parts = ranked.prefix(max(0, limit)).map { item in
            let label = "\(item.identity.name)×\(item.uses)"
            return item.estimatedCostUSD.map { "\(label) \(formatCost($0))" } ?? label
        }
        let hidden = ranked.count - parts.count
        if hidden > 0 {
            parts.append("+\(hidden)")
        }
        return parts.joined(separator: " · ")
    }

    /// Formats a USD amount as described above.
    public static func formatCost(_ usd: Double) -> String {
        guard usd >= 0.01 else {
            return "<$0.01"
        }
        let style = FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(2))
            .grouping(.never)
            .locale(Locale(identifier: "en_US_POSIX"))
        return "$" + usd.formatted(style)
    }
}
