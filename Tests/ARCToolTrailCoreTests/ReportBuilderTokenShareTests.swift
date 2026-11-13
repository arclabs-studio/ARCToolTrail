//
//  ReportBuilderTokenShareTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 13/11/2026.
//

import ARCToolTrailCore
import Foundation
import Testing

/// Weighted units, session shares, context weight and window points of `ReportBuilder`
/// (hand oracles in the spec comments below and in `SampleSession`).
struct ReportBuilderTokenShareTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeSUT(prices: PriceTable? = nil) throws -> ReportBuilder {
        try ReportBuilder(prices: prices ?? PriceTable.bundled())
    }

    private func item(_ name: String, in category: ToolCategory, of report: SessionReport) throws -> ReportItem {
        try #require(report.items.first { $0.identity.category == category && $0.identity.name == name })
    }

    private static let sessionWeighted = 23790.0

    @Test("Weighted units per item follow the hand oracle", .tags(.unit, .critical),
          arguments: [(ToolCategory.mcp, "firecrawl", 8020.0), (.skill, "plugin-authoring", 2520.0),
                      (.subagent, "Explore", 7780.0), (.builtin, "Bash", 780.0), (.plugin, "slack:slack", 780.0),
                      (.builtin, "Read", 0.0)])
    func weightedPerItem(category: ToolCategory, name: String, expected: Double) throws {
        // Given the fixture session
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(), now: now)

        // Then weighted units equal the hand-computed value (same with or without cost-state)
        #expect(try isClose(item(name, in: category, of: report).weighted, to: expected))
        let unscaled = sut.build(SampleSession.make(costState: nil), now: now)
        #expect(try isClose(item(name, in: category, of: unscaled).weighted, to: expected))
    }

    @Test("Session totals: sessionTokens, sessionWeighted, attributedWeighted", .tags(.unit, .critical))
    func sessionTotals() throws {
        // Given the fixture session
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(), now: now)

        // Then every call (main + subagent) is counted, and attributed units are below the session units
        #expect(report.sessionTokens == TokenUsage(input: 140, output: 2100, cacheRead: 18000,
                                                   cacheWrite5m: 3400, cacheWrite1h: 4000))
        #expect(isClose(report.sessionWeighted, to: Self.sessionWeighted))
        #expect(isClose(report.attributedWeighted, to: 19880))
        #expect(report.attributedWeighted <= report.sessionWeighted)
        let sum = report.items.reduce(0) { $0 + $1.weighted }
        #expect(isClose(report.attributedWeighted, to: sum))
    }

    @Test("sessionShare is weighted over sessionWeighted and the shares sum to at most 1",
          .tags(.unit, .critical)) func sessionShares() throws {
        // Given the fixture session
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(), now: now)

        // Then firecrawl = 8020 / 23790 and the total share is 19880 / 23790 (~0.8357) <= 1
        #expect(try isClose(item("firecrawl", in: .mcp, of: report).sessionShare, to: 8020.0 / 23790.0))
        #expect(try isClose(item("Explore", in: .subagent, of: report).sessionShare, to: 7780.0 / 23790.0))
        #expect(try isClose(item("Read", in: .builtin, of: report).sessionShare, to: 0))
        let total = report.items.reduce(0) { $0 + $1.sessionShare }
        #expect(isClose(total, to: 19880.0 / 23790.0))
        #expect(total <= 1)
    }

    @Test("A session with zero weighted units gives every item a share of 0", .tags(.unit)) func zeroSessionWeighted()
    throws {
        // Given a session with no usage at all: one call with a tool use and zero tokens
        let empty = APICall(messageId: "m1", model: SampleSession.opus, usage: .zero,
                            toolUses: [ToolUse(id: "t1", name: "Bash")], timestamp: nil)
        let session = ParsedSession(sessionId: "s", calls: [empty], subagents: [], costState: nil)
        let sut = try makeSUT()

        // When building
        let report = sut.build(session, now: now)

        // Then shares are 0, not NaN
        #expect(report.sessionWeighted == 0)
        #expect(report.items.allSatisfy { $0.sessionShare == 0 })
    }

    @Test("Unpriced models are weighted with the default ratios", .tags(.unit, .critical)) func unpricedWeighting()
    throws {
        // Given an empty price table and a call with output 100 and a tool use
        let call = APICall(messageId: "m1", model: SampleSession.opus, usage: TokenUsage(input: 4, output: 100),
                           toolUses: [ToolUse(id: "t1", name: "Bash")], timestamp: nil)
        let sut = try makeSUT(prices: PriceTable(models: [:]))

        // When building
        let report = sut.build(ParsedSession(sessionId: "s", calls: [call], subagents: [], costState: nil),
                               now: now)

        // Then USD is unavailable but units still exist: output 100 x default ratio 5 = 500; session adds input 4
        #expect(report.costSource == .unavailable)
        #expect(try isClose(item("Bash", in: .builtin, of: report).weighted, to: 500))
        #expect(isClose(report.sessionWeighted, to: 504))
    }

    @Test("weightedPerUse divides by main-thread uses when some uses are inside subagents",
          .tags(.unit, .critical)) func perUseExcludesSubagentUses() throws {
        // Given: m1 (opus, out 100) runs Bash on the main thread, m2 (opus, in 50) follows; a subagent
        // thread (unmatched) also runs Bash once. Bash: uses 2, in subagents 1, weighted = 100x5 + 50 = 550
        let m1 = APICall(messageId: "m1", model: SampleSession.opus, usage: TokenUsage(output: 100),
                         toolUses: [ToolUse(id: "t1", name: "Bash")], timestamp: nil)
        let m2 = APICall(messageId: "m2", model: SampleSession.opus, usage: TokenUsage(input: 50),
                         toolUses: [], timestamp: nil)
        let s1 = APICall(messageId: "s1", model: SampleSession.sonnet, usage: TokenUsage(output: 10),
                         toolUses: [ToolUse(id: "st1", name: "Bash")], timestamp: nil)
        let thread = SubagentThread(agentId: "z", parentToolUseId: "unknown", agentType: "Plan", calls: [s1])
        let session = ParsedSession(sessionId: "s", calls: [m1, m2], subagents: [thread], costState: nil)
        let sut = try makeSUT()

        // When building
        let report = sut.build(session, now: now)

        // Then d = 2 - 1 = 1, so weightedPerUse is 550 and not 275
        let bash = try item("Bash", in: .builtin, of: report)
        #expect(bash.uses == 2)
        #expect(bash.usesInSubagents == 1)
        #expect(isClose(bash.weighted, to: 550))
        #expect(isClose(bash.weightedPerUse, to: 550))
        // And session = 500 + 50 + 50 (sonnet output 10 x 5) = 600
        #expect(isClose(report.sessionWeighted, to: 600))
    }

    @Test("weightedPerUse falls back to all uses when every use is inside a subagent, and plain division otherwise",
          .tags(.unit)) func perUseFallback() throws {
        // Given the fixture session
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(), now: now)

        // Then Read (1 use, 1 in a subagent, 0 units) is 0, firecrawl is 8020 / 1
        #expect(try isClose(item("Read", in: .builtin, of: report).weightedPerUse, to: 0))
        #expect(try isClose(item("firecrawl", in: .mcp, of: report).weightedPerUse, to: 8020))
        #expect(try isClose(item("Explore", in: .subagent, of: report).weightedPerUse, to: 7780))
    }

    @Test("Context carry and live context follow the compactions of the session", .tags(.unit, .critical),
          arguments: [(ToolCategory.mcp, "firecrawl", 3020.0, 0.0), (.skill, "plugin-authoring", 0.0, 0.0),
                      (.subagent, "Explore", 1000.0, 0.0), (.builtin, "Bash", 0.0, 230.0),
                      (.plugin, "slack:slack", 0.0, 230.0)])
    func contextFields(category: ToolCategory, name: String, carry: Double, live: Double) throws {
        // Given the fixture session (compactions [3])
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(), now: now)

        // Then Explore carry is 0 (B1) + the subagent's 1000 cache reads; others follow the attributor oracle
        let entry = try item(name, in: category, of: report)
        #expect(isClose(entry.contextCarry, to: carry))
        #expect(isClose(entry.liveContextTokens, to: live))
    }

    @Test("Agent item: cache reads leave attributedTokens and USD and go to contextCarry", .tags(.unit, .critical))
    func agentConsistency() throws {
        // Given the fixture session without cost-state (price table)
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(costState: nil), now: now)

        // Then Explore has cacheRead 0 and carry 1000; its USD is B1 (0.01008) + sonnet part (0.01052)
        let explore = try item("Explore", in: .subagent, of: report)
        #expect(explore.attributedTokens.cacheRead == 0)
        #expect(isClose(explore.contextCarry, to: 1000))
        #expect(isClose(explore.estimatedCostUSD, to: 0.0206))
    }

    @Test("Without a baseline there is no window delta, window points or live share", .tags(.unit, .critical))
    func withoutWindows() throws {
        // Given the fixture session
        let sut = try makeSUT()

        // When building without windows
        let report = sut.build(SampleSession.make(), now: now)

        // Then the optional fields are nil
        #expect(report.windowDelta == nil)
        #expect(report.contextWindowSize == nil)
        #expect(report.items.allSatisfy { $0.windowPoints == nil && $0.liveContextShare == nil })
    }

    @Test("With a baseline, window points are scaled by session share and live share uses the context size",
          .tags(.unit, .critical)) func withWindows() throws {
        // Given a baseline that saw 5h 10 -> 12 (2.0 pp), 7d 5 -> 5.5 (0.5 pp) and a 1000-token context window
        var baseline = WindowBaseline()
        let reset5h = Date(timeIntervalSince1970: 1_794_405_600)
        let reset7d = Date(timeIntervalSince1970: 1_794_733_200)
        for (five, seven) in [(10.0, 5.0), (12.0, 5.5)] {
            baseline.record(StatuslineInput(sessionId: SampleSession.sessionId, transcriptPath: nil, cwd: nil,
                                            contextWindowSize: 1000,
                                            fiveHour: WindowSample(usedPercentage: five, resetsAt: reset5h),
                                            sevenDay: WindowSample(usedPercentage: seven, resetsAt: reset7d)))
        }
        let sut = try makeSUT()

        // When building with it
        let report = sut.build(SampleSession.make(), windows: baseline, now: now)

        // Then the report carries the delta and size, firecrawl gets 2.0 x 8020/23790 and 0.5 x 8020/23790
        #expect(report.windowDelta == WindowDelta(fiveHour: 2.0, sevenDay: 0.5))
        #expect(report.contextWindowSize == 1000)
        let firecrawl = try item("firecrawl", in: .mcp, of: report)
        #expect(try isClose(#require(firecrawl.windowPoints).fiveHour, to: 2.0 * 8020.0 / 23790.0))
        #expect(try isClose(#require(firecrawl.windowPoints).sevenDay, to: 0.5 * 8020.0 / 23790.0))
        // And live share = live tokens / size: Bash 230 / 1000, firecrawl 0
        #expect(try isClose(item("Bash", in: .builtin, of: report).liveContextShare, to: 0.23))
        #expect(isClose(firecrawl.liveContextShare, to: 0))
    }

    @Test("A baseline with only a context size gives live share but no window points", .tags(.unit))
    func contextSizeWithoutWindows() throws {
        // Given a baseline that only saw a context window size
        var baseline = WindowBaseline()
        baseline.record(StatuslineInput(sessionId: nil, transcriptPath: nil, cwd: nil, contextWindowSize: 1000))
        let sut = try makeSUT()

        // When building with it
        let report = sut.build(SampleSession.make(), windows: baseline, now: now)

        // Then windowDelta and windowPoints are nil while the live share is available
        #expect(report.windowDelta == nil)
        #expect(report.items.allSatisfy { $0.windowPoints == nil })
        #expect(try isClose(item("Bash", in: .builtin, of: report).liveContextShare, to: 0.23))
    }

    @Test("Within a category items are ordered by weighted units, not USD", .tags(.unit, .critical))
    func weightedOrdering() throws {
        // Given Xray on sonnet (output 200 -> 1000 units, 0.002 USD) and Yankee on opus (output 120 -> 600 units,
        // 0.0024 USD): the dearer in USD is the lighter in units
        let calls = [APICall(messageId: "m1", model: SampleSession.sonnet, usage: TokenUsage(output: 200),
                             toolUses: [ToolUse(id: "x", name: "Xray")], timestamp: nil),
                     APICall(messageId: "m2", model: SampleSession.opus, usage: TokenUsage(output: 120),
                             toolUses: [ToolUse(id: "y", name: "Yankee")], timestamp: nil)]
        let sut = try makeSUT()

        // When building
        let report = sut.build(ParsedSession(sessionId: "s", calls: calls, subagents: [], costState: nil),
                               now: now)

        // Then the heavier item comes first although it costs less
        #expect(report.items.map(\.identity.name) == ["Xray", "Yankee"])
        #expect(try isClose(item("Xray", in: .builtin, of: report).weighted, to: 1000))
        #expect(try isClose(item("Yankee", in: .builtin, of: report).weighted, to: 600))
        #expect(try isClose(item("Xray", in: .builtin, of: report).estimatedCostUSD, to: 0.002))
        #expect(try isClose(item("Yankee", in: .builtin, of: report).estimatedCostUSD, to: 0.0024))
    }
}
