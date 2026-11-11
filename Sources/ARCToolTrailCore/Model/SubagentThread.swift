//
//  SubagentThread.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// The calls made by one subagent, linked to the `Agent` tool use that launched it.
public struct SubagentThread: Hashable, Codable, Sendable {
    /// Agent id from the subagent transcript file name.
    public let agentId: String
    /// `toolUseId` from the subagent `.meta.json`, when present.
    public let parentToolUseId: String?
    /// `agentType` from the subagent `.meta.json`, when present.
    public let agentType: String?
    /// API calls of the subagent.
    public let calls: [APICall]

    public init(agentId: String, parentToolUseId: String?, agentType: String?, calls: [APICall]) {
        self.agentId = agentId
        self.parentToolUseId = parentToolUseId
        self.agentType = agentType
        self.calls = calls
    }
}
