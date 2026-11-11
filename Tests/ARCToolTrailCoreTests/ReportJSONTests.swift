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
        let keys = ["attributedCostUSD", "cleanup", "costSource", "generatedAt", "items", "sessionCostUSD",
                    "sessionId"]
        let positions = keys.compactMap { text.range(of: "\"\($0)\"")?.lowerBound }
        #expect(positions.count == keys.count)
        #expect(positions == positions.sorted())
    }
}
