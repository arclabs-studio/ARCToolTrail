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

    /// Weighted units decide the order; USD never shows (spec change: tokens, not dollars, are the metric).
    private var threeItems: [ReportItem] {
        [ReportFactory.item("Read", .builtin, uses: 2, cost: nil),
         ReportFactory.item("Bash", .builtin, uses: 5, cost: 0.004, weighted: 780, sessionShare: 0.04),
         ReportFactory.item("firecrawl", .mcp, uses: 3, cost: 0.123, weighted: 8000, sessionShare: 0.4)]
    }

    @Test("Lists items by weighted units with count and session share, zero share omitted",
          .tags(.unit, .critical)) func rendersItems() {
        // Given three items (input order differs from weighted order; Read has no units)
        let sut = makeSUT(threeItems)

        // When rendering with the default limit of 4
        let line = StatuslineRenderer.render(sut)

        // Then heaviest first, joined by " · ", no USD, no suffix
        #expect(line == "firecrawl×3 40% · Bash×5 4% · Read×2")
    }

    @Test("A share under half a percent shows as <1%", .tags(.unit)) func tinyShare() {
        // Given an item with 0.3 % of the session
        let sut = makeSUT([ReportFactory.item("Bash", .builtin, uses: 1, cost: nil, weighted: 3, sessionShare: 0.003)])

        // Then the share reads <1%
        #expect(StatuslineRenderer.render(sut) == "Bash×1 <1%")
    }

    @Test("Window points appear when the 5h delta and the share are positive", .tags(.unit, .critical))
    func windowPoints() {
        // Given a 5h delta of 2.0 pp: firecrawl 0.4 x 2.0 = 0.8, Bash 0.04 x 2.0 = 0.08 -> 0.1
        let sut = ReportFactory.report(items: threeItems, windowDelta: WindowDelta(fiveHour: 2.0, sevenDay: 0.5))

        // When rendering
        let line = StatuslineRenderer.render(sut)

        // Then points follow the share; Read (share 0) has none
        #expect(line == "firecrawl×3 40% ~0.8pp5h · Bash×5 4% ~0.1pp5h · Read×2")
    }

    @Test("No 5h points when the 5h delta is zero or missing", .tags(.unit),
          arguments: [WindowDelta(fiveHour: 0, sevenDay: 1), WindowDelta(fiveHour: nil, sevenDay: 1)])
    func noPointsWithoutFiveHourDelta(delta: WindowDelta) {
        // Given a report whose 5h delta is 0 or nil
        let sut = ReportFactory.report(items: threeItems, windowDelta: delta)

        // When rendering
        // Then no pp5h shows
        #expect(StatuslineRenderer.render(sut) == "firecrawl×3 40% · Bash×5 4% · Read×2")
    }

    @Test("Weighted units beat USD in the ranking", .tags(.unit, .critical)) func weightedBeatsCost() {
        // Given a cheap-in-USD but heavy item and a dear-in-USD but light one
        let sut = makeSUT([ReportFactory.item("Dear", .builtin, uses: 1, cost: 0.5, weighted: 100, sessionShare: 0.1),
                           ReportFactory.item("Heavy", .builtin, uses: 1, cost: 0.01, weighted: 900,
                                              sessionShare: 0.9)])

        // Then Heavy is first and no dollar sign appears
        #expect(StatuslineRenderer.render(sut) == "Heavy×1 90% · Dear×1 10%")
    }

    @Test("Items beyond the limit collapse into · +N", .tags(.unit, .critical),
          arguments: [(1, "firecrawl×3 40% · +2"),
                      (2, "firecrawl×3 40% · Bash×5 4% · +1")]) func truncates(limit: Int, expected: String) {
        // Given three items
        let sut = makeSUT(threeItems)

        // When rendering with a smaller limit
        let line = StatuslineRenderer.render(sut, limit: limit)

        // Then the remainder is counted
        #expect(line == expected)
    }

    @Test("Ties on weighted units: more uses first, then name", .tags(.unit)) func tieBreaking() {
        // Given three items with equal (zero) weighted units: Beta x4, Alpha x4, Zed x9
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
