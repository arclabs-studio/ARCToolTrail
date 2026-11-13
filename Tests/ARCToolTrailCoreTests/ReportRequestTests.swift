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

    private func makeSUT(transcript: URL, windowsDirectory: URL?) -> ReportRequest {
        ReportRequest(transcript: transcript, cacheDirectory: nil, pricesOverride: nil, claudeJSON: nil,
                      settingsJSON: nil, projectPath: nil, loadedList: nil, windowsDirectory: windowsDirectory)
    }

    @Test("windowsDirectory feeds the saved baseline of the parsed session into the report",
          .tags(.integration, .critical)) func usesSavedBaseline() throws {
        // Given a saved baseline (5h 10 -> 12, size 1000) named after the fixture's session id
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        var baseline = WindowBaseline()
        let reset = Date(timeIntervalSince1970: 1_794_405_600)
        for used in [10.0, 12.0] {
            baseline.record(StatuslineInput(sessionId: nil, transcriptPath: nil, cwd: nil, contextWindowSize: 1000,
                                            fiveHour: WindowSample(usedPercentage: used, resetsAt: reset)))
        }
        try baseline.save(to: WindowBaseline.url(in: temp.url, sessionId: SampleSession.sessionId))
        let sut = try makeSUT(transcript: Fixtures.transcript(), windowsDirectory: temp.url)

        // When running
        let report = try sut.run(now: Date(timeIntervalSince1970: 0))

        // Then window data and live share come through
        #expect(report.windowDelta == WindowDelta(fiveHour: 2, sevenDay: nil))
        #expect(report.contextWindowSize == 1000)
        let bash = try #require(report.items.first { $0.identity.name == "Bash" })
        #expect(isClose(bash.liveContextShare, to: 0.23))
    }

    @Test("Without windowsDirectory, or without a file for the session, there is no window data",
          .tags(.integration)) func noBaseline() throws {
        // Given an empty directory
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let transcript = try Fixtures.transcript()

        // When running with nil and with the empty directory
        let none = try makeSUT(transcript: transcript, windowsDirectory: nil).run()
        let empty = try makeSUT(transcript: transcript, windowsDirectory: temp.url).run()

        // Then neither has window data
        #expect(none.windowDelta == nil && none.contextWindowSize == nil)
        #expect(empty.windowDelta == nil && empty.contextWindowSize == nil)
    }
}
