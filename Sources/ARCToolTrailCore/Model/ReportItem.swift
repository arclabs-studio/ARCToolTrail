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

    public init(identity: ToolIdentity,
                uses: Int = 0,
                usesInSubagents: Int = 0,
                firstUse: Date? = nil,
                lastUse: Date? = nil,
                attributedTokens: TokenUsage = .zero,
                estimatedCostUSD: Double? = nil) {
        self.identity = identity
        self.uses = uses
        self.usesInSubagents = usesInSubagents
        self.firstUse = firstUse
        self.lastUse = lastUse
        self.attributedTokens = attributedTokens
        self.estimatedCostUSD = estimatedCostUSD
    }
}
