//
//  ParsedSession.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Everything tooltrail reads from one session on disk.
public struct ParsedSession: Hashable, Codable, Sendable {
    public let sessionId: String
    /// Calls of the main thread, in order.
    public let calls: [APICall]
    public let subagents: [SubagentThread]
    /// Last `cost-state` record, if Claude Code wrote one yet.
    public let costState: CostState?
    /// Index into `calls` of the first call after each `compact_boundary` record, ascending.
    public let compactions: [Int]

    public init(sessionId: String,
                calls: [APICall],
                subagents: [SubagentThread],
                costState: CostState?,
                compactions: [Int] = []) {
        self.sessionId = sessionId
        self.calls = calls
        self.subagents = subagents
        self.costState = costState
        self.compactions = compactions
    }
}
