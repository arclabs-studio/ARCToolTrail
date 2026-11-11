//
//  ReportRequestTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation
import Testing
@testable import ARCToolTrailCore

@Suite("ReportRequest")
struct ReportRequestTests {
    @Test("Runs loader, prices and inventory together on the fixture", .tags(.integration, .critical))
    func endToEnd() throws {
        // Given the fixture and a ~/.claude.json listing firecrawl and revenuecat for /work
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let claude = try temp
            .write(#"{"mcpServers":{"firecrawl":{}},"projects":{"/work":{"mcpServers":{"revenuecat":{}}}}}"#,
                   as: "claude.json")
        let sut = try ReportRequest(transcript: Fixtures.transcript(),
                                    cacheDirectory: nil,
                                    pricesOverride: nil,
                                    claudeJSON: claude,
                                    settingsJSON: nil,
                                    projectPath: "/work",
                                    loadedList: nil)

        // When running it
        let report = try sut.run(now: Date(timeIntervalSince1970: 0))

        // Then the fixture's cost-state total and the unused server come through
        #expect(report.sessionId == "00000000-0000-4000-8000-000000000001")
        #expect(report.costSource == .costState)
        #expect(isClose(report.sessionCostUSD, to: 0.2))
        #expect(report.items.contains { $0.identity.name == "firecrawl" })
        #expect(report.cleanup == [CleanupCandidate(kind: .mcpServer, name: "revenuecat")])
    }
}
