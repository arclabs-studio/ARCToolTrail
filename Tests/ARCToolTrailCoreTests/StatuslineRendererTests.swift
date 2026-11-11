//
//  StatuslineRendererTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Testing

struct StatuslineRendererTests {
    private func makeSUT(_ items: [ReportItem]) -> SessionReport {
        ReportFactory.report(items: items)
    }

    private var threeItems: [ReportItem] {
        [ReportFactory.item("Read", .builtin, uses: 2, cost: nil),
         ReportFactory.item("Bash", .builtin, uses: 5, cost: 0.004),
         ReportFactory.item("firecrawl", .mcp, uses: 3, cost: 0.123)]
    }

    @Test("Formats cost as dollars, sub-cent as <$0.01", .tags(.unit, .critical),
          arguments: [(0.123, "$0.12"), (0.126, "$0.13"), (0.004, "<$0.01"), (0.0099, "<$0.01"),
                      (0.01, "$0.01"), (0.1, "$0.10"),
                      (12.5, "$12.50")]) func formatCost(usd: Double,
                                                         expected: String) {
        // Given an amount
        // When formatting
        // Then it follows the documented shape
        #expect(StatuslineRenderer.formatCost(usd) == expected)
    }

    @Test("Lists items by cost with count, unknown cost omitted", .tags(.unit, .critical)) func rendersItems() {
        // Given three items (input order differs from cost order; Read has no cost)
        let sut = makeSUT(threeItems)

        // When rendering with the default limit of 4
        let line = StatuslineRenderer.render(sut)

        // Then dearest first, joined by " · ", no suffix
        #expect(line == "firecrawl×3 $0.12 · Bash×5 <$0.01 · Read×2")
    }

    @Test("Items beyond the limit collapse into · +N", .tags(.unit, .critical),
          arguments: [(1, "firecrawl×3 $0.12 · +2"),
                      (2,
                       "firecrawl×3 $0.12 · Bash×5 <$0.01 · +1")]) func truncates(limit: Int,
                                                                                  expected: String) {
        // Given three items
        let sut = makeSUT(threeItems)

        // When rendering with a smaller limit
        let line = StatuslineRenderer.render(sut, limit: limit)

        // Then the remainder is counted
        #expect(line == expected)
    }

    @Test("Ties on cost: more uses first, then name", .tags(.unit)) func tieBreaking() {
        // Given three items with unknown cost: Beta x4, Alpha x4, Zed x9
        let sut = makeSUT([ReportFactory.item("Beta", .builtin, uses: 4, cost: nil),
                           ReportFactory.item("Alpha", .builtin, uses: 4, cost: nil),
                           ReportFactory.item("Zed", .builtin, uses: 9, cost: nil)])

        // When rendering
        let line = StatuslineRenderer.render(sut)

        // Then Zed (most uses), then Alpha before Beta
        #expect(line == "Zed×9 · Alpha×4 · Beta×4")
    }

    @Test("No items renders the placeholder", .tags(.unit)) func empty() {
        // Given a report without items
        let sut = makeSUT([])

        // When rendering
        // Then the placeholder shows
        #expect(StatuslineRenderer.render(sut) == "no tools yet")
    }
}
