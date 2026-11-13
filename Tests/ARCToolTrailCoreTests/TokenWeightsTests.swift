//
//  TokenWeightsTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 13/11/2026.
//

import Foundation
import Testing
@testable import ARCToolTrailCore

struct TokenWeightsTests {
    private let opus = SampleSession.opus
    private let sonnet = SampleSession.sonnet

    private func makeSUT() throws -> PriceTable {
        try PriceTable.bundled()
    }

    /// Bundled prices: for both opus and sonnet, output 5x, cache read 0.05x, 5m 1.25x, 1h 2x of input.
    @Test("Fixture attributed shares in input-token units", .tags(.unit, .critical),
          arguments: [(TokenUsage(input: 20, output: 400, cacheWrite1h: 3000), 8020.0), // 20 + 2000 + 6000
                      (TokenUsage(input: 20, output: 300, cacheWrite1h: 500), 2520.0), // 20 + 1500 + 1000
                      (TokenUsage(input: 30, output: 100, cacheWrite5m: 200), 780.0), // 30 + 500 + 250
                      (TokenUsage(input: 130, output: 1300, cacheRead: 17000, cacheWrite5m: 2400,
                                  cacheWrite1h: 4000), 18480.0)]) // 130 + 6500 + 850 + 3000 + 8000
    func opusUnits(usage: TokenUsage, expected: Double) throws {
        // Given the bundled prices
        let prices = try makeSUT()

        // When weighing opus usage
        let units = TokenWeights.units(of: usage, model: opus, prices: prices)

        // Then it equals the hand-computed units
        #expect(isClose(units, to: expected))
    }

    @Test("Sonnet subagent thread: 5310 with cache reads, 5260 without", .tags(.unit, .critical))
    func sonnetUnits() throws {
        // Given the bundled prices and the subagent thread's usage
        let prices = try makeSUT()
        let withReads = TokenUsage(input: 10, output: 800, cacheRead: 1000, cacheWrite5m: 1000)
        let withoutReads = TokenUsage(input: 10, output: 800, cacheWrite5m: 1000)

        // When weighing
        // Then 10 + 4000 + 50 + 1250 = 5310 and 10 + 4000 + 1250 = 5260
        #expect(isClose(TokenWeights.units(of: withReads, model: sonnet, prices: prices), to: 5310))
        #expect(isClose(TokenWeights.units(of: withoutReads, model: sonnet, prices: prices), to: 5260))
    }

    @Test("Per-model dictionary is the sum of each model's units", .tags(.unit, .critical))
    func dictionarySum() throws {
        // Given Explore's tokens: B1 share on opus and the sonnet thread without cache reads
        let prices = try makeSUT()
        let tokens = [opus: TokenUsage(input: 20, output: 300, cacheWrite1h: 500),
                      sonnet: TokenUsage(input: 10, output: 800, cacheWrite5m: 1000)]

        // When weighing
        // Then 2520 + 5260 = 7780; an empty dictionary is 0
        #expect(isClose(TokenWeights.units(of: tokens, prices: prices), to: 7780))
        #expect(TokenWeights.units(of: [:], prices: prices) == 0)
    }

    @Test("Ratios come from the model's own price row", .tags(.unit, .critical)) func customPrices() {
        // Given a model priced input 2, output 8 (4x), cache read 0.5 (0.25x), 5m x1.5, 1h x3
        let prices = PriceTable(models: ["m": ModelPrice(inputPerMTok: 2, outputPerMTok: 8, cacheReadPerMTok: 0.5,
                                                         cacheWrite5mMultiplier: 1.5, cacheWrite1hMultiplier: 3)])
        let usage = TokenUsage(input: 10, output: 5, cacheRead: 100, cacheWrite5m: 10, cacheWrite1h: 10)

        // When weighing
        let units = TokenWeights.units(of: usage, model: "m", prices: prices)

        // Then 10 + 5x4 + 100x0.25 + 10x1.5 + 10x3 = 10 + 20 + 25 + 15 + 30 = 100
        #expect(isClose(units, to: 100))
    }

    @Test("Unpriced model uses the default ratios: output 5, read 0.1, 5m 1.25, 1h 2", .tags(.unit, .critical))
    func unpricedDefaults() {
        // Given an empty price table and mixed usage
        let usage = TokenUsage(input: 10, output: 10, cacheRead: 100, cacheWrite5m: 10, cacheWrite1h: 10)

        // When weighing an unknown model
        let units = TokenWeights.units(of: usage, model: "mystery", prices: PriceTable(models: [:]))

        // Then 10 + 50 + 10 + 12.5 + 20 = 102.5
        #expect(isClose(units, to: 102.5))
    }

    @Test("A zero input price falls back to the default ratios instead of dividing by zero", .tags(.unit))
    func zeroInputPrice() {
        // Given a model whose input price is 0
        let prices = PriceTable(models: ["free": ModelPrice(inputPerMTok: 0, outputPerMTok: 8, cacheReadPerMTok: 1)])

        // When weighing output 10 and read 100
        let units = TokenWeights.units(of: TokenUsage(output: 10, cacheRead: 100), model: "free", prices: prices)

        // Then default ratios apply: 10x5 + 100x0.1 = 60
        #expect(isClose(units, to: 60))
    }
}
