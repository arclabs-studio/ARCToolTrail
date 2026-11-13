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

        // Then there are exactly two header rows (token-share columns, spec change) and one row per item
        let header = "| Tool | Uses | % sess | Units/use | Ctx carry | % ctx | ~5h pp | ~7d pp | Est. cost |"
        #expect(note.components(separatedBy: header).count - 1 == 2)
        let separator = "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
        #expect(note.components(separatedBy: separator).count - 1 == 2)
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

    // MARK: - Token-share output

    private func richReport(windowDelta: WindowDelta?) -> SessionReport {
        let firecrawl = ReportFactory.item("firecrawl", .mcp, uses: 3, cost: 0.123, server: "firecrawl",
                                           weighted: 8000, sessionShare: 0.4, weightedPerUse: 2666.7,
                                           contextCarry: 3020, liveContextShare: 0.23,
                                           windowPoints: WindowDelta(fiveHour: 0.8, sevenDay: nil))
        return ReportFactory.report(items: [firecrawl], sessionWeighted: 20000, attributedWeighted: 8000,
                                    windowDelta: windowDelta)
    }

    private func frontMatter(_ note: String) throws -> [String] {
        let body = note.dropFirst(4)
        let closing = try #require(body.range(of: "\n---\n"))
        return body[body.startIndex ..< closing.lowerBound].split(separator: "\n").map(String.init)
    }

    @Test("Item rows carry the token-share cells in column order", .tags(.unit, .critical)) func rowCells() throws {
        // Given the rich report
        let note = MarkdownNoteRenderer.render(richReport(windowDelta: nil))

        // When locating the firecrawl row
        let row = try #require(note.split(separator: "\n").map(String.init).first { $0.hasPrefix("| firecrawl |") })
        let cells = row.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }

        // Then name, uses, share, units/use, carry, live share, 5h pp, 7d pp (nil), cost
        #expect(cells == ["firecrawl", "3", "40%", "2.7k", "3.0k", "23%", "0.8", "—", "$0.12"])
    }

    @Test("Front matter adds session_weighted and the window points after date, before tags",
          .tags(.unit, .critical)) func frontMatterWindows() throws {
        // Given a window delta of 2.0 / 0.5 and 20000 weighted units
        let note = MarkdownNoteRenderer.render(richReport(windowDelta: WindowDelta(fiveHour: 2.0, sevenDay: 0.5)))

        // When reading the front matter
        let lines = try frontMatter(note)
        let keys = lines.map { $0.split(separator: ":").first.map(String.init) ?? "" }

        // Then values are formatted as documented and keys keep this order
        #expect(lines.contains("session_weighted: 20000"))
        #expect(lines.contains("window_5h_pp: 2.00"))
        #expect(lines.contains("window_7d_pp: 0.50"))
        #expect(keys == ["type", "session", "date", "session_weighted", "window_5h_pp", "window_7d_pp", "tags"])
    }

    @Test("Window keys are left out when the delta or one window is missing", .tags(.unit)) func frontMatterWithout()
    throws {
        // Given no delta, and a delta with only 7d
        let none = try frontMatter(MarkdownNoteRenderer.render(richReport(windowDelta: nil)))
        let sevenOnly = try frontMatter(MarkdownNoteRenderer
            .render(richReport(windowDelta: WindowDelta(fiveHour: nil, sevenDay: 0.5))))

        // Then session_weighted stays, missing windows have no key
        #expect(none.contains("session_weighted: 20000"))
        #expect(!none.contains { $0.hasPrefix("window_") })
        #expect(!sevenOnly.contains { $0.hasPrefix("window_5h_pp") })
        #expect(sevenOnly.contains("window_7d_pp: 0.50"))
    }

    @Test("Footer carries the session line, the window line and the unchanged USD line", .tags(.unit, .critical))
    func footer() {
        // Given 8000 of 20000 units attributed (40 %) and a window delta
        let note = MarkdownNoteRenderer.render(richReport(windowDelta: WindowDelta(fiveHour: 2.0, sevenDay: 0.5)))

        // Then each line shows (Markdown ends the session and window lines with a period)
        #expect(note.contains("Session 20.0k units (price-weighted tokens), 40% attributed to tools."))
        #expect(note.contains("Window use this session: 5h +2.0 pp · 7d +0.5 pp "
                + "(estimate: includes parallel sessions; weighting is a price proxy)."))
        #expect(note.contains("Attributed $0.10 of session $0.20 (estimate, source: `costState`)."))
    }
}
