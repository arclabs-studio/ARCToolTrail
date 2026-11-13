//
//  ReportBuilderTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation
import Testing

struct ReportBuilderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeSUT(prices: PriceTable? = nil) throws -> ReportBuilder {
        try ReportBuilder(prices: prices ?? PriceTable.bundled())
    }

    private func item(_ name: String, in category: ToolCategory, of report: SessionReport) throws -> ReportItem {
        try #require(report.items.first { $0.identity.category == category && $0.identity.name == name })
    }

    // MARK: - Hand oracle (see SampleSession for per-token prices)

    //
    // Price-table cost of each attributed share (opus):
    //   firecrawl  (in 20, out 400, 1h 3000)        = 0.00008 + 0.008 + 0.024  = 0.03208
    //   B1 / B2    (in 20, out 300, 1h 500)         = 0.00008 + 0.006 + 0.004  = 0.01008
    //   C1 / C2    (in 30, out 100, 5m 200)         = 0.00012 + 0.002 + 0.001  = 0.00312
    //   main-thread attributed total                = 0.03208 + 2x0.01008 + 2x0.00312 = 0.05848
    // Whole opus main thread (in 130, out 1300, read 17000, 5m 2400, 1h 4000):
    //   0.00052 + 0.026 + 0.0034 + 0.012 + 0.032                              = 0.07392
    // Subagent (sonnet; in 10, out 800, read 1000, 5m 1000)                    = 0.01062
    // Session price-table total = 0.07392 + 0.01062                            = 0.08454
    // Agent consistency (token-share spec): the Explore item is priced WITHOUT the thread's cache reads,
    // which move to its contextCarry. Sonnet part priced = (in 10, out 800, 5m 1000) = 0.00002 + 0.008 + 0.0025
    // = 0.01052 (it was 0.01062 when cache reads were included).
    // Explore item = B1 share + sonnet part                                    = 0.01008 + 0.01052 = 0.0206
    // Attributed (price table) = 0.05848 + 0.01052                             = 0.069
    //
    // Cost-state scaling: opus factor = 0.15 / 0.07392 (~2.029221); sonnet factor = 0.05 / 0.01062
    // (whole-model cost, unchanged), so the Explore sonnet part scales to 0.01052 x (0.05 / 0.01062).
    //
    // Weighted units (opus and sonnet both: out 5x, read 0.05x, 5m 1.25x, 1h 2x):
    //   firecrawl 20 + 2000 + 6000 = 8020 · plugin-authoring 20 + 1500 + 1000 = 2520
    //   Explore 2520 + (10 + 4000 + 1250 = 5260) = 7780 · Bash = slack = 30 + 500 + 250 = 780 · Read 0
    //   session: opus main 130 + 6500 + 850 + 3000 + 8000 = 18480; sonnet sub 10 + 4000 + 50 + 1250 = 5310
    //   sessionWeighted = 23790 · attributedWeighted = 8020 + 2520 + 7780 + 780 + 780 = 19880

    private static let opusFactor = 0.15 / 0.07392
    private static let sonnetFactor = 0.05 / 0.01062
    private static let sonnetPart = 0.01052 * sonnetFactor

    // MARK: - Items and categories

    @Test("Fixture session: items land in the right categories", .tags(.unit, .critical)) func categories() throws {
        // Given the hand-built fixture session
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(), now: now)

        // Then each tool is in its category, one item each (Read is only used inside the subagent)
        #expect(report.items(in: .mcp).map(\.identity.name) == ["firecrawl"])
        #expect(report.items(in: .skill).map(\.identity.name) == ["plugin-authoring"])
        #expect(report.items(in: .plugin).map(\.identity.name) == ["slack:slack"])
        #expect(report.items(in: .subagent).map(\.identity.name) == ["Explore"])
        #expect(Set(report.items(in: .builtin).map(\.identity.name)) == ["Bash", "Read"])
        #expect(report.items.count == 6)
        #expect(report.sessionId == SampleSession.sessionId)
        #expect(report.generatedAt == now)
    }

    @Test("Read inside the subagent counts as a use but carries no cost", .tags(.unit,
                                                                                .critical)) func readInSubagent() throws {
        // Given the fixture session
        let sut = try makeSUT()
        let report = sut.build(SampleSession.make(), now: now)

        // When looking at Read
        let read = try item("Read", in: .builtin, of: report)

        // Then 1 use, all inside a subagent, and no cost or tokens of its own
        #expect(read.uses == 1)
        #expect(read.usesInSubagents == 1)
        #expect((read.estimatedCostUSD ?? 0) == 0)
        #expect(read.attributedTokens.total == 0)
    }

    @Test("Main-thread uses are counted with first and last use", .tags(.unit)) func mainThreadCounts() throws {
        // Given the fixture session
        let sut = try makeSUT()
        let report = sut.build(SampleSession.make(), now: now)

        // When looking at firecrawl (one use, in msg_A at 09:00:01)
        let firecrawl = try item("firecrawl", in: .mcp, of: report)

        // Then counts and times match
        #expect(firecrawl.uses == 1)
        #expect(firecrawl.usesInSubagents == 0)
        #expect(firecrawl.firstUse == SampleSession.time(1))
        #expect(firecrawl.lastUse == SampleSession.time(1))
        #expect(firecrawl.identity.server == "firecrawl")
        let slack = try item("slack:slack", in: .plugin, of: report)
        #expect(slack.identity.plugin == "slack")
    }

    @Test("Explore subagent item carries the full subagent token cost plus its own call share", .tags(.unit, .critical))
    func subagentTokens() throws {
        // Given the fixture session
        let sut = try makeSUT()
        let report = sut.build(SampleSession.make(), now: now)

        // When looking at Explore
        let explore = try item("Explore", in: .subagent, of: report)

        // Then tokens = B1 share (in 20, out 300, 1h 500) + subagent tokens WITHOUT cache reads
        // (in 10, out 800, 5m 1000); the thread's 1000 cache reads moved to contextCarry (spec change)
        #expect(explore.attributedTokens == TokenUsage(input: 30, output: 1100, cacheRead: 0,
                                                       cacheWrite5m: 1000, cacheWrite1h: 500))
        #expect(explore.uses == 1)
    }

    // MARK: - Price table only

    @Test("Without cost-state, costs come from the price table", .tags(.unit,
                                                                       .critical)) func priceTableCosts() throws {
        // Given the fixture session without a cost-state record
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(costState: nil), now: now)

        // Then source and totals follow the hand oracle
        #expect(report.costSource == .priceTable)
        #expect(isClose(report.sessionCostUSD, to: 0.08454))
        #expect(isClose(report.attributedCostUSD, to: 0.069))
        #expect(try isClose(item("firecrawl", in: .mcp, of: report).estimatedCostUSD, to: 0.03208))
        #expect(try isClose(item("plugin-authoring", in: .skill, of: report).estimatedCostUSD, to: 0.01008))
        #expect(try isClose(item("slack:slack", in: .plugin, of: report).estimatedCostUSD, to: 0.00312))
        #expect(try isClose(item("Explore", in: .subagent, of: report).estimatedCostUSD, to: 0.0206))
        #expect(try isClose(item("Bash", in: .builtin, of: report).estimatedCostUSD, to: 0.00312))
    }

    // MARK: - Cost-state scaling

    @Test("With cost-state, each model is scaled to its reported cost", .tags(.unit,
                                                                              .critical)) func costStateScaling() throws {
        // Given the fixture session with cost-state (total 0.2; opus 0.15; sonnet 0.05)
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(), now: now)

        // Then opus items are price-table cost x (0.15 / 0.07392); the sonnet part is 0.01052 x (0.05 / 0.01062)
        #expect(report.costSource == .costState)
        #expect(try isClose(item("firecrawl", in: .mcp, of: report).estimatedCostUSD,
                            to: 0.03208 * Self.opusFactor))
        #expect(try isClose(item("plugin-authoring", in: .skill, of: report).estimatedCostUSD,
                            to: 0.01008 * Self.opusFactor))
        #expect(try isClose(item("slack:slack", in: .plugin, of: report).estimatedCostUSD,
                            to: 0.00312 * Self.opusFactor))
        #expect(try isClose(item("Bash", in: .builtin, of: report).estimatedCostUSD,
                            to: 0.00312 * Self.opusFactor))
        #expect(try isClose(item("Explore", in: .subagent, of: report).estimatedCostUSD,
                            to: 0.01008 * Self.opusFactor + Self.sonnetPart))
    }

    @Test("With cost-state, session cost is the reported total and attribution never exceeds it",
          .tags(.unit, .critical))
    func costStateTotals() throws {
        // Given the fixture session with cost-state
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(), now: now)

        // Then session = 0.2; attributed = 0.05848 x opusFactor + sonnet part (~0.16820) = sum of items <= 0.2
        #expect(isClose(report.sessionCostUSD, to: 0.2))
        #expect(isClose(report.attributedCostUSD, to: 0.05848 * Self.opusFactor + Self.sonnetPart))
        let sum = report.items.reduce(0) { $0 + ($1.estimatedCostUSD ?? 0) }
        #expect(isClose(report.attributedCostUSD, to: sum))
        let attributed = try #require(report.attributedCostUSD)
        let session = try #require(report.sessionCostUSD)
        #expect(attributed <= session)
    }

    // MARK: - Ordering

    @Test("Items are ordered by category, then cost descending", .tags(.unit,
                                                                       .critical)) func fixtureOrdering() throws {
        // Given the fixture session
        let sut = try makeSUT()

        // When building (with and without cost-state)
        let scaled = sut.build(SampleSession.make(), now: now)
        let unscaled = sut.build(SampleSession.make(costState: nil), now: now)

        // Then skill, mcp, plugin, subagent, then builtin with Bash (has cost) before Read (none)
        let expected = ["plugin-authoring", "firecrawl", "slack:slack", "Explore", "Bash", "Read"]
        #expect(scaled.items.map(\.identity.name) == expected)
        #expect(unscaled.items.map(\.identity.name) == expected)
    }

    @Test("Within a category: higher cost first, equal cost by name", .tags(.unit)) func costThenNameOrdering() throws {
        // Given: m1 emits Zed (output 100); m2 emits Amy and Bob (output 100, 50 each); m3 text-only, no new input
        // Costs (opus, output 20e-6): Zed 100 -> 0.002; Amy = Bob = 50 -> 0.001
        let calls = [call("m1", output: 100, tools: ["Zed"], at: 1),
                     call("m2", output: 100, tools: ["Amy", "Bob"], at: 2),
                     call("m3", output: 0, tools: [], at: 3)]
        let session = ParsedSession(sessionId: "s", calls: calls, subagents: [], costState: nil)
        let sut = try makeSUT()

        // When building
        let report = sut.build(session, now: now)

        // Then Zed (dearest) first, then Amy and Bob alphabetically
        #expect(report.items.map(\.identity.name) == ["Zed", "Amy", "Bob"])
        #expect(isClose(report.items.first?.estimatedCostUSD, to: 0.002))
    }

    private func call(_ id: String, output: Double, tools: [String], at seconds: Double) -> APICall {
        APICall(messageId: id,
                model: SampleSession.opus,
                usage: TokenUsage(output: output),
                toolUses: tools.map { ToolUse(id: "\(id)-\($0)", name: $0) },
                timestamp: SampleSession.time(seconds))
    }

    // MARK: - Subagent matching

    @Test("An unmatched subagent thread becomes one use of its agentType (default general-purpose)", .tags(.unit),
          arguments: [("Plan", "Plan"), (nil, "general-purpose")] as [(String?, String)])
    func unmatchedSubagent(agentType: String?,
                           expectedName: String) throws {
        // Given a session without main calls and a subagent whose parent tool use is unknown;
        // its one sonnet call has output 100 -> 100 x 10e-6 = 0.001
        let thread = SubagentThread(agentId: "z",
                                    parentToolUseId: "toolu_unknown",
                                    agentType: agentType,
                                    calls: [APICall(messageId: "s1", model: SampleSession.sonnet,
                                                    usage: TokenUsage(output: 100), toolUses: [], timestamp: nil)])
        let session = ParsedSession(sessionId: "s", calls: [], subagents: [thread], costState: nil)
        let sut = try makeSUT()

        // When building
        let report = sut.build(session, now: now)

        // Then one subagent item with one use and the subagent's cost
        let entry = try item(expectedName, in: .subagent, of: report)
        #expect(report.items.count == 1)
        #expect(entry.uses == 1)
        #expect(isClose(entry.estimatedCostUSD, to: 0.001))
        #expect(isClose(report.sessionCostUSD, to: 0.001))
    }

    // MARK: - No prices

    @Test("Empty price table: source unavailable, no USD anywhere, tokens kept",
          .tags(.unit, .critical)) func unavailable() throws {
        // Given a price table with no models and a session without cost-state
        let sut = try makeSUT(prices: PriceTable(models: [:]))

        // When building
        let report = sut.build(SampleSession.make(costState: nil), now: now)

        // Then costs are nil but tokens and counts are still reported
        #expect(report.costSource == .unavailable)
        #expect(report.sessionCostUSD == nil)
        #expect(report.attributedCostUSD == nil)
        #expect(!report.items.isEmpty)
        #expect(report.items.allSatisfy { $0.estimatedCostUSD == nil })
        let firecrawl = try item("firecrawl", in: .mcp, of: report)
        #expect(firecrawl.attributedTokens == TokenUsage(input: 20, output: 400, cacheWrite1h: 3000))
        #expect(firecrawl.uses == 1)
    }

    // MARK: - Cleanup

    @Test("Cleanup lists inventory entries nothing used", .tags(.unit, .critical)) func cleanup() throws {
        // Given an inventory with firecrawl + revenuecat servers and slack + caveman plugins
        let inventory = ConfigInventory(mcpServers: ["firecrawl", "revenuecat"], plugins: ["slack", "caveman"])
        let sut = try makeSUT()

        // When building (firecrawl and slack:slack are used)
        let report = sut.build(SampleSession.make(), inventory: inventory, now: now)

        // Then only the unused ones remain
        #expect(Set(report.cleanup) == [CleanupCandidate(kind: .mcpServer, name: "revenuecat"),
                                        CleanupCandidate(kind: .plugin, name: "caveman")])
        #expect(report.cleanup.count == 2)
    }

    @Test("No inventory means no cleanup candidates", .tags(.unit)) func noInventory() throws {
        // Given no inventory
        let sut = try makeSUT()

        // When building
        let report = sut.build(SampleSession.make(), now: now)

        // Then cleanup is empty
        #expect(report.cleanup.isEmpty)
    }

    // MARK: - End to end on the real fixture files

    @Test("Loaded fixture produces the cost-state report end to end", .tags(.integration,
                                                                            .critical)) func endToEnd() throws {
        // Given the fixture loaded from disk (parser + loader) and the bundled prices
        let session = try SessionLoader(cacheDirectory: nil).load(transcript: Fixtures.transcript())
        let sut = try makeSUT()

        // When building
        let report = sut.build(session, now: now)

        // Then the same hand-computed numbers hold
        #expect(report.costSource == .costState)
        #expect(isClose(report.sessionCostUSD, to: 0.2))
        #expect(isClose(report.attributedCostUSD, to: 0.05848 * Self.opusFactor + Self.sonnetPart))
        #expect(try isClose(item("Explore", in: .subagent, of: report).estimatedCostUSD,
                            to: 0.01008 * Self.opusFactor + Self.sonnetPart))
        let read = try item("Read", in: .builtin, of: report)
        #expect(read.usesInSubagents == 1)
    }
}
