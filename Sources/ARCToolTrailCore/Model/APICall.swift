//
//  APICall.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// One model response (deduplicated by `message.id`) with its usage and tool uses.
public struct APICall: Hashable, Codable, Sendable {
    /// `message.id` of the response.
    public let messageId: String
    /// Model id that served the call.
    public let model: String
    /// Billed tokens of the call.
    public let usage: TokenUsage
    /// Tool uses emitted by the call, in transcript order.
    public var toolUses: [ToolUse]
    /// Timestamp of the first transcript record of the call.
    public let timestamp: Date?

    public init(messageId: String, model: String, usage: TokenUsage, toolUses: [ToolUse], timestamp: Date?) {
        self.messageId = messageId
        self.model = model
        self.usage = usage
        self.toolUses = toolUses
        self.timestamp = timestamp
    }
}
