//
//  StatuslineRenderer.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// One-line summary for the Claude Code statusline.
///
/// Format: the top `limit` items by weighted units (ties: more uses first, then name), each as
/// `<name>×<uses>`, then its share of the session (`18%`, omitted at 0) and, when the session has a
/// 5-hour window delta above 0, its estimated window points (`~0.4pp5h`). Items are joined by ` · `;
/// when items are left out, ` · +<count>` is appended. With no items: `no tools yet`. No USD.
public enum StatuslineRenderer {
    public static func render(_ report: SessionReport, limit: Int = 4) -> String {
        guard !report.items.isEmpty else {
            return "no tools yet"
        }
        let ranked = report.items.sorted { lhs, rhs in
            if lhs.weighted != rhs.weighted {
                return lhs.weighted > rhs.weighted
            }
            if lhs.uses != rhs.uses {
                return lhs.uses > rhs.uses
            }
            return lhs.identity.name < rhs.identity.name
        }
        let fiveHour = report.windowDelta?.fiveHour ?? 0
        var parts = ranked.prefix(max(0, limit)).map { item in
            var part = "\(item.identity.name)×\(item.uses)"
            if item.sessionShare > 0 {
                part += " " + UsageFormat.share(item.sessionShare)
                if fiveHour > 0 {
                    part += " ~" + UsageFormat.points(item.sessionShare * fiveHour) + "pp5h"
                }
            }
            return part
        }
        let hidden = ranked.count - parts.count
        if hidden > 0 {
            parts.append("+\(hidden)")
        }
        return parts.joined(separator: " · ")
    }
}
