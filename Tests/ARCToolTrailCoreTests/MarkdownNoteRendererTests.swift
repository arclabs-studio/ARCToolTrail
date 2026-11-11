//
//  MarkdownNoteRendererTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation
import Testing

struct MarkdownNoteRendererTests {
    private func makeSUT(cleanup: [CleanupCandidate] = []) -> SessionReport {
        ReportFactory.report(items: [ReportFactory.item("firecrawl", .mcp, uses: 3, cost: 0.123, server: "firecrawl"),
                                     ReportFactory.item("Bash", .builtin, uses: 5, cost: 0.004)],
                             cleanup: cleanup)
    }

    @Test("Starts with YAML front matter carrying type, session, date and tags",
          .tags(.unit, .critical)) func frontMatter() throws {
        // Given a report for session sess-123
        let report = makeSUT()

        // When rendering
        let note = MarkdownNoteRenderer.render(report)

        // Then the note opens with a closed front matter block
        #expect(note.hasPrefix("---\n"))
        let body = note.dropFirst(3)
        let closing = try #require(body.range(of: "\n---\n"))
        let front = String(body[body.startIndex ..< closing.lowerBound])
        #expect(front.contains("type: claude-session-tools"))
        #expect(front.contains("session: sess-123"))
        #expect(front.contains("\ndate:"))
        #expect(front.contains("tags: [claude-code, tooltrail]"))
    }

    @Test("One table per non-empty category with the documented header", .tags(.unit, .critical)) func tables() {
        // Given a report with two non-empty categories
        let report = makeSUT()

        // When rendering
        let note = MarkdownNoteRenderer.render(report)

        // Then there are exactly two header rows and one row per item
        let header = "| Tool | Uses | Est. cost |"
        #expect(note.components(separatedBy: header).count - 1 == 2)
        let lines = note.split(separator: "\n").map(String.init)
        #expect(lines.contains { $0.hasPrefix("| firecrawl |") && $0.contains("3") })
        #expect(lines.contains { $0.hasPrefix("| Bash |") && $0.contains("5") })
    }

    @Test("Cleanup section appears only when there are candidates", .tags(.unit, .critical)) func cleanupSection() {
        // Given reports with and without candidates
        let without = MarkdownNoteRenderer.render(makeSUT())
        let with = MarkdownNoteRenderer.render(makeSUT(cleanup: [CleanupCandidate(kind: .mcpServer,
                                                                                  name: "revenuecat-zzz")]))

        // Then the heading and the name show only in the second
        #expect(with.contains("## Cleanup suggestions"))
        #expect(with.contains("revenuecat-zzz"))
        #expect(!without.contains("## Cleanup suggestions"))
        #expect(!without.contains("revenuecat-zzz"))
    }
}
