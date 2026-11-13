//
//  ReportItem.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Aggregated usage of one tool in a session.
public struct ReportItem: Hashable, Codable, Sendable {
    public let identity: ToolIdentity
    /// Number of tool uses (subagent-internal uses included).
    public var uses: Int
    /// Uses made from inside a subagent; their cost is rolled up to the subagent item.
    public var usesInSubagents: Int
    public var firstUse: Date?
    public var lastUse: Date?
    /// Tokens attributed to this tool.
    public var attributedTokens: TokenUsage
    /// Estimated USD cost; `nil` when no price is known for the models involved.
    public var estimatedCostUSD: Double?
    /// `attributedTokens` in weighted units (see ``TokenWeights``).
    public var weighted: Double
    /// `weighted / SessionReport.sessionWeighted`; 0 when the session has no tokens.
    public var sessionShare: Double
    /// `weighted` per use made outside subagents (per use when every use was inside one).
    public var weightedPerUse: Double
    /// Raw tokens this tool's results made later calls re-read (see ``CostAttributor``); for a
    /// subagent, plus every cache read of its own thread.
    public var contextCarry: Double
    /// Raw tokens this tool added since the last compaction.
    public var liveContextTokens: Double
    /// `liveContextTokens / context_window_size`; `nil` when the window size is unknown.
    public var liveContextShare: Double?
    /// Estimated window points: the session's window use × `sessionShare`. `nil` without a baseline.
    public var windowPoints: WindowDelta?

    public init(identity: ToolIdentity,
                uses: Int = 0,
                usesInSubagents: Int = 0,
                firstUse: Date? = nil,
                lastUse: Date? = nil,
                attributedTokens: TokenUsage = .zero,
                estimatedCostUSD: Double? = nil,
                weighted: Double = 0,
                sessionShare: Double = 0,
                weightedPerUse: Double = 0,
                contextCarry: Double = 0,
                liveContextTokens: Double = 0,
                liveContextShare: Double? = nil,
                windowPoints: WindowDelta? = nil) {
        self.identity = identity
        self.uses = uses
        self.usesInSubagents = usesInSubagents
        self.firstUse = firstUse
        self.lastUse = lastUse
        self.attributedTokens = attributedTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.weighted = weighted
        self.sessionShare = sessionShare
        self.weightedPerUse = weightedPerUse
        self.contextCarry = contextCarry
        self.liveContextTokens = liveContextTokens
        self.liveContextShare = liveContextShare
        self.windowPoints = windowPoints
    }
}
