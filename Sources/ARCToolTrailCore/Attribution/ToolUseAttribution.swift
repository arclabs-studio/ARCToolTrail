//
//  ToolUseAttribution.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Tokens attributed to one tool use, keyed by the model that billed them.
public struct ToolUseAttribution: Hashable, Sendable {
    public let toolUse: ToolUse
    public let tokensByModel: [String: TokenUsage]
    /// Timestamp of the call that emitted the tool use.
    public let timestamp: Date?
    /// Tokens the tool result added, times the later calls that re-read them before a compaction.
    public let contextCarry: Double
    /// Tokens the tool result added, when they were added after the last compaction (still in context).
    public let liveContextTokens: Double

    public init(toolUse: ToolUse,
                tokensByModel: [String: TokenUsage],
                timestamp: Date?,
                contextCarry: Double = 0,
                liveContextTokens: Double = 0) {
        self.toolUse = toolUse
        self.tokensByModel = tokensByModel
        self.timestamp = timestamp
        self.contextCarry = contextCarry
        self.liveContextTokens = liveContextTokens
    }
}
