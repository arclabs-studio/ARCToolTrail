//
//  CostAttributorTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation
import Testing

struct CostAttributorTests {
    private let opus = SampleSession.opus
    private let sonnet = SampleSession.sonnet

    private func makeSUT(_ calls: [APICall]) -> [String: ToolUseAttribution] {
        Dictionary(uniqueKeysWithValues: CostAttributor.attribute(calls).map { ($0.toolUse.id, $0) })
    }

    /// Hand oracle on the fixture main thread (all opus):
    ///   A (out 400)  -> tool A1;           next call B adds in 20, write1h 3000
    ///   B (out 600)  -> tools B1,B2;       next call C adds in 40, write1h 1000 -> halves: in 20, 1h 500
    ///   C (out 200)  -> tools C1,C2;       next call D adds in 60, write5m 400  -> halves: in 30, 5m 200
    ///   D has no tools.
    ///   A1 = in 20, out 400, 1h 3000
    ///   B1 = B2 = in 20, out 300, 1h 500
    ///   C1 = C2 = in 30, out 100, 5m 200
    @Test("Fixture main thread: output and next-call new context split per tool use", .tags(.unit, .critical),
          arguments: [("toolu_A1", TokenUsage(input: 20, output: 400, cacheWrite1h: 3000)),
                      ("toolu_B1", TokenUsage(input: 20, output: 300, cacheWrite1h: 500)),
                      ("toolu_B2", TokenUsage(input: 20, output: 300, cacheWrite1h: 500)),
                      ("toolu_C1", TokenUsage(input: 30, output: 100, cacheWrite5m: 200)),
                      ("toolu_C2", TokenUsage(input: 30, output: 100, cacheWrite5m: 200))])
    func fixtureAttribution(toolUseId: String,
                            expected: TokenUsage) throws {
        // Given the fixture main-thread calls
        // When attributing
        let result = makeSUT(SampleSession.mainCalls)

        // Then the tool use holds exactly the hand-computed tokens, all billed to opus
        let attribution = try #require(result[toolUseId])
        #expect(attribution.tokensByModel == [opus: expected])
    }

    @Test("Fixture: five attributions, timestamps from the emitting call", .tags(.unit)) func fixtureShape() {
        // Given the fixture main-thread calls
        // When attributing
        let result = makeSUT(SampleSession.mainCalls)

        // Then only the five tool uses appear, stamped with their call's time
        #expect(Set(result.keys) == ["toolu_A1", "toolu_B1", "toolu_B2", "toolu_C1", "toolu_C2"])
        #expect(result["toolu_A1"]?.timestamp == SampleSession.msgA.timestamp)
        #expect(result["toolu_C2"]?.timestamp == SampleSession.msgC.timestamp)
    }

    @Test("Cache reads are never attributed and the total stays below the thread total", .tags(.unit, .critical))
    func neverExceedsThreadTotal() {
        // Given the fixture main-thread calls (thread total 130 + 1300 + 17000 + 2400 + 4000 = 24830)
        // When attributing
        let result = CostAttributor.attribute(SampleSession.mainCalls)
        let attributed = result.flatMap(\.tokensByModel.values).reduce(TokenUsage.zero, +)

        // Then cache reads are zero and attributed = 120 in + 1200 out + 400 5m + 4000 1h = 5720
        #expect(attributed.cacheRead == 0)
        #expect(attributed == TokenUsage(input: 120, output: 1200, cacheWrite5m: 400, cacheWrite1h: 4000))
        let threadTotal = SampleSession.mainCalls.reduce(0) { $0 + $1.usage.total }
        #expect(threadTotal == 24830)
        #expect(attributed.total <= threadTotal)
    }

    @Test("Next call is billed at its own model", .tags(.unit, .critical)) func mixedModels() throws {
        // Given an opus call with one tool use followed by a sonnet call with one tool use
        let first = APICall(messageId: "m1", model: opus, usage: TokenUsage(input: 1, output: 100, cacheRead: 5),
                            toolUses: [ToolUse(id: "t1", name: "Bash")], timestamp: nil)
        let second = APICall(messageId: "m2", model: sonnet,
                             usage: TokenUsage(input: 50, output: 30, cacheRead: 999, cacheWrite5m: 20,
                                               cacheWrite1h: 10),
                             toolUses: [ToolUse(id: "t2", name: "Read")], timestamp: nil)

        // When attributing
        let result = makeSUT([first, second])

        // Then t1 = opus output 100 + sonnet new context (in 50, 5m 20, 1h 10); t2 = sonnet output 30 only
        let t1 = try #require(result["t1"])
        let t2 = try #require(result["t2"])
        #expect(t1.tokensByModel == [opus: TokenUsage(output: 100),
                                     sonnet: TokenUsage(input: 50, cacheWrite5m: 20, cacheWrite1h: 10)])
        #expect(t2.tokensByModel == [sonnet: TokenUsage(output: 30)])
    }

    @Test("Output is split evenly among n tool uses", .tags(.unit)) func evenSplit() {
        // Given one call with 3 tool uses and output 90, last in the thread
        let call = APICall(messageId: "m1", model: opus, usage: TokenUsage(input: 7, output: 90),
                           toolUses: [ToolUse(id: "a", name: "Bash"), ToolUse(id: "b", name: "Read"),
                                      ToolUse(id: "c", name: "Edit")],
                           timestamp: nil)

        // When attributing
        let result = makeSUT([call])

        // Then each gets 30 output and nothing else (no next call, input is never attributed to itself)
        #expect(result.count == 3)
        for id in ["a", "b", "c"] {
            #expect(result[id]?.tokensByModel == [opus: TokenUsage(output: 30)])
        }
    }

    @Test("Calls without tool uses attribute nothing; empty thread gives nothing", .tags(.unit)) func noTools() {
        // Given a text-only call and an empty thread
        let call = APICall(messageId: "m1", model: opus, usage: TokenUsage(input: 7, output: 90),
                           toolUses: [], timestamp: nil)

        // When attributing
        // Then both results are empty
        #expect(CostAttributor.attribute([call]).isEmpty)
        #expect(CostAttributor.attribute([]).isEmpty)
    }
}
