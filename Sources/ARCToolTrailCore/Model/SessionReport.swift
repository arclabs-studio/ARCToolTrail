//
//  SessionReport.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Per-tool usage of one Claude Code session: share of the session's weighted tokens, context weight,
/// estimated rate-limit window points, and the estimated USD cost as secondary data.
public struct SessionReport: Hashable, Codable, Sendable {
    public let sessionId: String
    public let generatedAt: Date
    /// Items sorted by category, then by weighted units (highest first), then by name.
    public let items: [ReportItem]
    /// Whole-session cost: `cost-state` total when present, otherwise the price-table total.
    public let sessionCostUSD: Double?
    /// Sum of `estimatedCostUSD` over all items. Always ≤ `sessionCostUSD`.
    public let attributedCostUSD: Double?
    public let costSource: CostSource
    /// Configured MCP servers and plugins with no use in the session. Empty when no inventory was given.
    public let cleanup: [CleanupCandidate]
    /// Every token of every call, subagents included.
    public let sessionTokens: TokenUsage
    /// `sessionTokens` in weighted units (see ``TokenWeights``).
    public let sessionWeighted: Double
    /// Sum of `weighted` over all items. Always ≤ `sessionWeighted`.
    public let attributedWeighted: Double
    /// Window points used while this session ran (parallel sessions included); `nil` without a baseline.
    public let windowDelta: WindowDelta?
    /// Last `context_window_size` the statusline reported; `nil` when unknown.
    public let contextWindowSize: Int?

    public init(sessionId: String,
                generatedAt: Date,
                items: [ReportItem],
                sessionCostUSD: Double?,
                attributedCostUSD: Double?,
                costSource: CostSource,
                cleanup: [CleanupCandidate],
                sessionTokens: TokenUsage = .zero,
                sessionWeighted: Double = 0,
                attributedWeighted: Double = 0,
                windowDelta: WindowDelta? = nil,
                contextWindowSize: Int? = nil) {
        self.sessionId = sessionId
        self.generatedAt = generatedAt
        self.items = items
        self.sessionCostUSD = sessionCostUSD
        self.attributedCostUSD = attributedCostUSD
        self.costSource = costSource
        self.cleanup = cleanup
        self.sessionTokens = sessionTokens
        self.sessionWeighted = sessionWeighted
        self.attributedWeighted = attributedWeighted
        self.windowDelta = windowDelta
        self.contextWindowSize = contextWindowSize
    }

    /// Items of one category, in report order.
    public func items(in category: ToolCategory) -> [ReportItem] {
        items.filter { $0.identity.category == category }
    }
}
