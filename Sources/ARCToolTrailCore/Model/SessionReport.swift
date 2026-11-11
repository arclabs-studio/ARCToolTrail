//
//  SessionReport.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Per-tool usage and estimated cost of one Claude Code session.
public struct SessionReport: Hashable, Codable, Sendable {
    public let sessionId: String
    public let generatedAt: Date
    /// Items sorted by category, then by estimated cost (highest first), then by name.
    public let items: [ReportItem]
    /// Whole-session cost: `cost-state` total when present, otherwise the price-table total.
    public let sessionCostUSD: Double?
    /// Sum of `estimatedCostUSD` over all items. Always ≤ `sessionCostUSD`.
    public let attributedCostUSD: Double?
    public let costSource: CostSource
    /// Configured MCP servers and plugins with no use in the session. Empty when no inventory was given.
    public let cleanup: [CleanupCandidate]

    public init(sessionId: String,
                generatedAt: Date,
                items: [ReportItem],
                sessionCostUSD: Double?,
                attributedCostUSD: Double?,
                costSource: CostSource,
                cleanup: [CleanupCandidate]) {
        self.sessionId = sessionId
        self.generatedAt = generatedAt
        self.items = items
        self.sessionCostUSD = sessionCostUSD
        self.attributedCostUSD = attributedCostUSD
        self.costSource = costSource
        self.cleanup = cleanup
    }

    /// Items of one category, in report order.
    public func items(in category: ToolCategory) -> [ReportItem] {
        items.filter { $0.identity.category == category }
    }
}
