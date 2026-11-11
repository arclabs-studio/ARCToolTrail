//
//  ReportFilesTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation
import Testing
@testable import ARCToolTrailCore

@Suite("ReportFiles")
struct ReportFilesTests {
    private func makeSUT(sessionId: String) -> SessionReport {
        // 1_700_000_000 s = 2023-11-14T22:13:20Z
        SessionReport(sessionId: sessionId,
                      generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                      items: [],
                      sessionCostUSD: nil,
                      attributedCostUSD: nil,
                      costSource: .unavailable,
                      cleanup: [])
    }

    @Test("Note file name is the UTC day plus the first 8 characters of the session id", .tags(.unit))
    func noteFileName() {
        // Given a report for a full UUID session
        let report = makeSUT(sessionId: "6495b37d-b24b-48b8-b35b-da95e32e89bb")

        // When naming its note
        let name = ReportFiles.noteFileName(for: report)

        // Then
        #expect(name == "2023-11-14 6495b37d.md")
    }

    @Test("Short session ids are used whole", .tags(.unit)) func shortId() {
        #expect(ReportFiles.noteFileName(for: makeSUT(sessionId: "s-1")) == "2023-11-14 s-1.md")
    }

    @Test("Default export goes to <cache>/exports/<session>.json", .tags(.unit)) func defaultExport() {
        // Given a cache directory
        let cache = URL(filePath: "/tmp/tooltrail-cache", directoryHint: .isDirectory)

        // When resolving the default export
        let url = ReportFiles.defaultExportURL(cacheDirectory: cache, sessionId: "abc")

        // Then
        #expect(url.path(percentEncoded: false) == "/tmp/tooltrail-cache/exports/abc.json")
    }
}
