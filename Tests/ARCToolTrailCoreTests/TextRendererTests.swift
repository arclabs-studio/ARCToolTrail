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
}
