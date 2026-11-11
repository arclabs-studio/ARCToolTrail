//
//  SampleSession.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation

/// Hand-built mirror of `Fixtures/synthetic-session`, written from the fixture numbers and not from
/// parser output. 2026-11-11T09:00:00Z = 1_794_387_600 (checked with `date -u -r`).
///
/// Price-table costs per token, opus-5-5: input 4e-6, output 20e-6, cache read 0.2e-6,
/// cache write 5m 5e-6, cache write 1h 8e-6. Sonnet-5-5: 2e-6, 10e-6, 0.1e-6, 2.5e-6, 4e-6.
enum SampleSession {
    static let opus = "claude-opus-5-5"
    static let sonnet = "claude-sonnet-5-5"
    static let sessionId = "00000000-0000-4000-8000-000000000001"

    static func time(_ secondsAfterNineAM: Double) -> Date {
        Date(timeIntervalSince1970: 1_794_387_600 + secondsAfterNineAM)
    }

    static let costState = CostState(totalCostUSD: 0.2, costByModel: [opus: 0.15, sonnet: 0.05])

    static let msgA = APICall(messageId: "msg_A",
                              model: opus,
                              usage: TokenUsage(input: 10, output: 400, cacheRead: 1000, cacheWrite5m: 2000),
                              toolUses: [ToolUse(id: "toolu_A1", name: "mcp__firecrawl__firecrawl_search")],
                              timestamp: time(1))
    static let msgB = APICall(messageId: "msg_B",
                              model: opus,
                              usage: TokenUsage(input: 20, output: 600, cacheRead: 3000, cacheWrite1h: 3000),
                              toolUses: [ToolUse(id: "toolu_B1", name: "Agent", subagentType: "Explore"),
                                         ToolUse(id: "toolu_B2", name: "Skill", skill: "plugin-authoring")],
                              timestamp: time(4))
    static let msgC = APICall(messageId: "msg_C",
                              model: opus,
                              usage: TokenUsage(input: 40, output: 200, cacheRead: 6000, cacheWrite1h: 1000),
                              toolUses: [ToolUse(id: "toolu_C1", name: "Bash"),
                                         ToolUse(id: "toolu_C2",
                                                 name: "mcp__plugin_slack_slack__slack_send_message")],
                              timestamp: time(30))
    static let msgD = APICall(messageId: "msg_D",
                              model: opus,
                              usage: TokenUsage(input: 60, output: 100, cacheRead: 7000, cacheWrite5m: 400),
                              toolUses: [],
                              timestamp: time(40))

    static let mainCalls = [msgA, msgB, msgC, msgD]

    static let msgS1 = APICall(messageId: "msg_S1",
                               model: sonnet,
                               usage: TokenUsage(input: 5, output: 300, cacheWrite5m: 1000),
                               toolUses: [ToolUse(id: "toolu_S1", name: "Read")],
                               timestamp: time(7))
    static let msgS2 = APICall(messageId: "msg_S2",
                               model: sonnet,
                               usage: TokenUsage(input: 5, output: 500, cacheRead: 1000),
                               toolUses: [],
                               timestamp: time(9))

    static let explore = SubagentThread(agentId: "a1",
                                        parentToolUseId: "toolu_B1",
                                        agentType: "Explore",
                                        calls: [msgS1, msgS2])

    static func make(costState: CostState? = SampleSession.costState) -> ParsedSession {
        ParsedSession(sessionId: sessionId, calls: mainCalls, subagents: [explore], costState: costState)
    }
}
