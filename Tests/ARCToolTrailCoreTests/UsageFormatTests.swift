//
//  UsageFormatTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 13/11/2026.
//

import Testing
@testable import ARCToolTrailCore

struct UsageFormatTests {
    @Test("Formats cost as dollars, sub-cent as <$0.01", .tags(.unit, .critical),
          arguments: [(0.123, "$0.12"), (0.126, "$0.13"), (0.004, "<$0.01"), (0.0099, "<$0.01"),
                      (0.01, "$0.01"), (0.1, "$0.10"), (12.5, "$12.50")]) func cost(usd: Double, expected: String) {
        // Given an amount
        // When formatting
        // Then it follows the documented shape
        #expect(UsageFormat.cost(usd) == expected)
    }

    @Test("Share: 0 is 0%, tiny is <1%, otherwise a rounded percent", .tags(.unit, .critical),
          arguments: [(0.0, "0%"), (0.0001, "<1%"), (0.0049, "<1%"), (0.006, "1%"), (0.04, "4%"),
                      (0.334, "33%"), (0.337, "34%"), (0.8357, "84%"), (1.0, "100%")])
    func share(value: Double, expected: String) {
        // Given a fraction
        // When formatting
        // Then it follows the documented shape
        #expect(UsageFormat.share(value) == expected)
    }

    @Test("Units: integer below 1000, k with one decimal below a million, M above", .tags(.unit, .critical),
          arguments: [(0.0, "0"), (780.0, "780"), (780.4, "780"), (999.0, "999"), (1000.0, "1.0k"),
                      (8020.0, "8.0k"), (23790.0, "23.8k"), (1_234_567.0, "1.2M")])
    func units(value: Double, expected: String) {
        // Given a number of weighted units
        // When formatting
        // Then it follows the documented shape
        #expect(UsageFormat.units(value) == expected)
    }

    /// An exact zero prints 0.0: "<0.1" would claim some use where there was none (changed after review).
    @Test("Points: 0.0 at zero, <0.1 below 0.05, otherwise one decimal", .tags(.unit, .critical),
          arguments: [(0.0, "0.0"), (0.04, "<0.1"), (0.06, "0.1"), (0.4, "0.4"), (2.0, "2.0"), (12.34, "12.3")])
    func points(value: Double, expected: String) {
        // Given percentage points
        // When formatting
        // Then it follows the documented shape
        #expect(UsageFormat.points(value) == expected)
    }
}
