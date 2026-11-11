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

    public init(toolUse: ToolUse, tokensByModel: [String: TokenUsage], timestamp: Date?) {
        self.toolUse = toolUse
        self.tokensByModel = tokensByModel
        self.timestamp = timestamp
    }
}
