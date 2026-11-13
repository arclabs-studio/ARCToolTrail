//
//  TextRendererTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation
import Testing

struct TextRendererTests {
    private func makeSUT(cleanup: [CleanupCandidate] = []) -> SessionReport {
        ReportFactory.report(items: [ReportFactory.item("firecrawl", .mcp, uses: 3, cost: 0.123, server: "firecrawl"),
                                     ReportFactory.item("Bash", .builtin, uses: 5, cost: 0.004)],
                             cleanup: cleanup)
    }

    @Test("Sections appear only for non-empty categories, with item rows",
          .tags(.unit, .critical)) func sectionsForNonEmptyCategories() {
        // Given a report with an MCP item and a builtin item only
        let report = makeSUT()

        // When rendering
        let text = TextRenderer.render(report)

        // Then those two titles and rows show; the other categories' titles do not
        #expect(text.contains(ToolCategory.mcp.title))
        #expect(text.contains(ToolCategory.builtin.title))
        #expect(text.contains("firecrawl"))
        #expect(text.contains("Bash"))
        for absent in [ToolCategory.skill, .plugin, .subagent] {
            #expect(!text.contains(absent.title), "unexpected section \(absent.title)")
        }
    }

    @Test("Sections follow category order", .tags(.unit)) func sectionOrder() throws {
        // Given the same report
        let text = TextRenderer.render(makeSUT())

        // When locating titles
        let mcp = try #require(text.range(of: ToolCategory.mcp.title))
        let builtin = try #require(text.range(of: ToolCategory.builtin.title))

        // Then MCP comes before Built-in
        #expect(mcp.lowerBound < builtin.lowerBound)
    }

    @Test("Cleanup candidates are listed only when present", .tags(.unit)) func cleanupList() {
        // Given reports with and without a cleanup candidate
        let without = TextRenderer.render(makeSUT())
        let with = TextRenderer.render(makeSUT(cleanup: [CleanupCandidate(kind: .plugin, name: "caveman-zzz")]))

        // Then the name appears only in the second
        #expect(with.contains("caveman-zzz"))
        #expect(!without.contains("caveman-zzz"))
    }

    // MARK: - Token-share columns

    private func inOrder(_ line: String, _ cells: [String]) -> Bool {
        var rest = Substring(line)
        for cell in cells {
            guard let found = rest.range(of: cell) else { return false }
            rest = rest[found.upperBound...]
        }
        return true
    }

    private func richReport(windowDelta: WindowDelta? = nil) -> SessionReport {
        let firecrawl = ReportFactory.item("firecrawl", .mcp, uses: 3, cost: 0.123, server: "firecrawl",
                                           usesInSubagents: 1, weighted: 8000, sessionShare: 0.4,
                                           weightedPerUse: 4000, contextCarry: 3020, liveContextTokens: 230,
                                           liveContextShare: 0.23,
                                           windowPoints: WindowDelta(fiveHour: 0.8, sevenDay: nil))
        let bash = ReportFactory.item("Bash", .builtin, uses: 5, cost: nil, weighted: 780, sessionShare: 0.04,
                                      weightedPerUse: 156)
        return ReportFactory.report(items: [firecrawl, bash], sessionWeighted: 20000, attributedWeighted: 8780,
                                    windowDelta: windowDelta)
    }

    @Test("Each section has the documented header row", .tags(.unit, .critical)) func headerRow() {
        // Given a report with two categories
        let text = TextRenderer.render(richReport())

        // When looking for header rows
        let headers = text.split(separator: "\n").map(String.init).filter { $0.contains("units/use") }

        // Then one per section, with the nine columns in order
        #expect(headers.count == 2)
        for header in headers {
            #expect(inOrder(header, ["Tool", "Uses", "%sess", "units/use", "ctx carry", "%ctx", "~5h pp", "~7d pp",
                                     "USD"]))
        }
    }

    @Test("Rows show uses, share, units per use, carry, live share, window points and USD", .tags(.unit, .critical))
    func rows() throws {
        // Given the rich report
        let lines = TextRenderer.render(richReport()).split(separator: "\n").map(String.init)

        // When locating the rows
        let firecrawl = try #require(lines.first { $0.contains("firecrawl") && $0.contains("×3") })
        let bash = try #require(lines.first { $0.contains("Bash") && $0.contains("×5") })

        // Then cells appear in column order: nil pp and nil ctx show "—", nil USD shows n/a
        #expect(inOrder(firecrawl, ["firecrawl", "×3 (1 sub)", "40%", "4.0k", "3.0k", "23%", "0.8", "—", "$0.12"]))
        #expect(inOrder(bash, ["Bash", "×5", "4%", "156", "0", "—", "—", "—", "n/a"]))
        #expect(!bash.contains("sub)"))
    }

    @Test("Footer: session units, share attributed, window line, then the unchanged USD line",
          .tags(.unit, .critical)) func footer() throws {
        // Given session 20000 units, 8780 attributed (44 %), and a window delta
        let text = TextRenderer.render(richReport(windowDelta: WindowDelta(fiveHour: 2.0, sevenDay: 0.5)))

        // Then the three lines appear in order
        #expect(text.contains("Session 20.0k units (price-weighted tokens), 44% attributed to tools"))
        #expect(text.contains("Window use this session: 5h +2.0 pp · 7d +0.5 pp "
                + "(estimate: includes parallel sessions; weighting is a price proxy)"))
        #expect(text.contains("Attributed $0.10 of session $0.20 (estimate, source: costState)"))
        let session = try #require(text.range(of: "units (price-weighted tokens)"))
        let window = try #require(text.range(of: "Window use this session"))
        let usd = try #require(text.range(of: "Attributed $"))
        #expect(session.lowerBound < window.lowerBound && window.lowerBound < usd.lowerBound)
    }

    @Test("Window line: absent without a delta, a missing window shows —", .tags(.unit)) func windowLineVariants() {
        // Given reports without a delta and with only a 7d delta
        let without = TextRenderer.render(richReport())
        let sevenOnly = TextRenderer.render(richReport(windowDelta: WindowDelta(fiveHour: nil, sevenDay: 0.5)))

        // Then the line is missing in the first and shows — for 5h in the second
        #expect(!without.contains("Window use this session"))
        #expect(sevenOnly.contains("Window use this session: 5h — · 7d +0.5 pp "))
    }
}
