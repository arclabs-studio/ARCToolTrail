//
//  ReportJSONTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation
import Testing

struct ReportJSONTests {
    private func makeSUT() -> SessionReport {
        ReportFactory.report(items: [ReportFactory.item("firecrawl", .mcp, uses: 3, cost: 0.125, server: "firecrawl"),
                                     ReportFactory.item("claude_ai_Linear", .mcp, uses: 1, cost: nil,
                                                        server: "claude_ai_Linear",
                                                        isConnector: true),
                                     ReportFactory.item("Bash", .builtin, uses: 5, cost: 0.004)],
                             cleanup: [CleanupCandidate(kind: .plugin, name: "caveman")])
    }

    @Test("Encode then decode returns an equal report", .tags(.unit, .critical)) func roundTrip() throws {
        // Given a report with whole-second dates, a nil cost and a cleanup entry
        let report = makeSUT()

        // When round-tripping through ReportJSON
        let data = try ReportJSON.encode(report)
        let decoded = try ReportJSON.decode(data)

        // Then nothing is lost
        #expect(decoded == report)
    }

    @Test("Dates are ISO 8601", .tags(.unit)) func isoDates() throws {
        // Given a report generated at epoch 1_700_000_000 = 2023-11-14T22:13:20Z
        let data = try ReportJSON.encode(makeSUT())

        // When reading the JSON text
        let text = try #require(String(bytes: data, encoding: .utf8))

        // Then the date is an ISO 8601 string
        #expect(text.contains("\"2023-11-14T22:13:20Z\""))
    }

    @Test("Top-level keys are sorted and output is stable", .tags(.unit)) func sortedKeys() throws {
        // Given a report
        let report = makeSUT()

        // When encoding twice
        let first = try ReportJSON.encode(report)
        let second = try ReportJSON.encode(report)
        let text = try #require(String(bytes: first, encoding: .utf8))

        // Then bytes are identical and keys appear in alphabetical order
        #expect(first == second)
        let keys = ["attributedCostUSD", "attributedWeighted", "cleanup", "costSource", "generatedAt", "items",
                    "sessionCostUSD", "sessionId", "sessionTokens", "sessionWeighted"]
        let positions = keys.compactMap { text.range(of: "\"\($0)\"")?.lowerBound }
        #expect(positions.count == keys.count)
        #expect(positions == positions.sorted())
    }

    @Test("Token-share fields round-trip and nil optionals are omitted", .tags(.unit, .critical))
    func tokenShareFields() throws {
        // Given a report with window data on one item, a half-missing report delta, and a plain item
        let withWindows = ReportFactory.item("firecrawl", .mcp, uses: 1, cost: nil, weighted: 8000,
                                             sessionShare: 0.4, weightedPerUse: 8000, contextCarry: 3020,
                                             liveContextTokens: 230, liveContextShare: 0.23,
                                             windowPoints: WindowDelta(fiveHour: 0.8, sevenDay: 0.2))
        let plain = ReportFactory.item("Bash", .builtin, uses: 1, cost: nil, weighted: 780)
        let report = ReportFactory.report(items: [withWindows, plain],
                                          sessionTokens: TokenUsage(input: 1, output: 2),
                                          sessionWeighted: 20000, attributedWeighted: 8780,
                                          windowDelta: WindowDelta(fiveHour: 2, sevenDay: nil),
                                          contextWindowSize: 1000)

        // When round-tripping
        let data = try ReportJSON.encode(report)
        let decoded = try ReportJSON.decode(data)
        let text = try #require(String(bytes: data, encoding: .utf8))

        // Then nothing is lost, the new keys appear, and nil optionals are not written
        #expect(decoded == report)
        for key in ["sessionWeighted", "attributedWeighted", "sessionTokens", "windowDelta", "contextWindowSize",
                    "weighted", "sessionShare", "weightedPerUse", "contextCarry", "liveContextTokens",
                    "liveContextShare", "windowPoints"] {
            #expect(text.contains("\"\(key)\""), "missing key \(key)")
        }
        // liveContextShare only on firecrawl; sevenDay only inside firecrawl's windowPoints (report delta has nil)
        #expect(text.components(separatedBy: "\"liveContextShare\"").count - 1 == 1)
        #expect(text.components(separatedBy: "\"sevenDay\"").count - 1 == 1)
    }
}
