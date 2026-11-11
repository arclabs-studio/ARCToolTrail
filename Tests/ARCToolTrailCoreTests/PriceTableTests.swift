//
//  PriceTableTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation
import Testing

struct PriceTableTests {
    private func makeSUT() throws -> PriceTable {
        try PriceTable.bundled()
    }

    /// Hand oracle, opus-5-5 (4 / 20 / 0.2 per MTok, cache write 5m 1.25x = 5, 1h 2x = 8):
    ///   input       1_000_000 x 4/M   = 4.0
    ///   output        100_000 x 20/M  = 2.0
    ///   cache read  2_000_000 x 0.2/M = 0.4
    ///   write 5m      400_000 x 5/M   = 2.0
    ///   write 1h      500_000 x 8/M   = 4.0
    ///   total                         = 12.4
    private static let usage = TokenUsage(input: 1_000_000, output: 100_000, cacheRead: 2_000_000,
                                          cacheWrite5m: 400_000, cacheWrite1h: 500_000)

    @Test("Bundled table prices opus and sonnet as documented", .tags(.unit, .critical)) func bundledPrices() throws {
        // Given the bundled table
        let sut = try makeSUT()

        // When looking up the two models the fixtures use
        let opus = sut.price(for: "claude-opus-5-5")
        let sonnet = sut.price(for: "claude-sonnet-5-5")

        // Then the per-MTok prices match prices.json
        #expect(opus == ModelPrice(inputPerMTok: 4, outputPerMTok: 20, cacheReadPerMTok: 0.2))
        #expect(sonnet == ModelPrice(inputPerMTok: 2, outputPerMTok: 10, cacheReadPerMTok: 0.1))
    }

    @Test("Computes exact USD cost across all five token classes", .tags(.unit, .critical)) func exactCost() throws {
        // Given the bundled table
        let sut = try makeSUT()

        // When pricing the hand-built usage on opus
        let cost = sut.cost(of: Self.usage, model: "claude-opus-5-5")

        // Then it equals 4.0 + 2.0 + 0.4 + 2.0 + 4.0
        #expect(isClose(cost, to: 12.4))
    }

    @Test("Sonnet fixture subagent usage costs 0.01062", .tags(.unit)) func sonnetCost() throws {
        // Given the subagent totals: input 10, output 800, cache read 1000, write 5m 1000
        let sut = try makeSUT()
        let usage = TokenUsage(input: 10, output: 800, cacheRead: 1000, cacheWrite5m: 1000)

        // When pricing on sonnet
        let cost = sut.cost(of: usage, model: "claude-sonnet-5-5")

        // Then 10x2e-6 + 800x10e-6 + 1000x0.1e-6 + 1000x2.5e-6 = 0.00002 + 0.008 + 0.0001 + 0.0025 = 0.01062
        #expect(isClose(cost, to: 0.01062))
    }

    @Test("Model ids are normalised before lookup", .tags(.unit),
          arguments: ["anthropic.claude-opus-5-5",
                      "claude-opus-5-5[1m]",
                      "claude-opus-5-5-20260101",
                      "anthropic.claude-opus-5-5-20260101[1m]"]) func normalisation(model: String) throws {
        // Given the bundled table
        let sut = try makeSUT()

        // When pricing under a decorated model id
        let cost = sut.cost(of: Self.usage, model: model)

        // Then the plain opus-5-5 price applies
        #expect(isClose(cost, to: 12.4))
    }

    @Test("Unknown model has no price and no cost", .tags(.unit)) func unknownModel() throws {
        // Given the bundled table
        let sut = try makeSUT()

        // When looking up a model that is not in it
        // Then price and cost are nil
        #expect(sut.price(for: "claude-unknown-9") == nil)
        #expect(sut.cost(of: Self.usage, model: "claude-unknown-9") == nil)
    }

    @Test("Override replaces one model and adds another, leaving the rest",
          .tags(.integration)) func overrideReplacesAndAdds() throws {
        // Given an override file replacing opus and adding a new model
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let file = try temp.write("""
        {"models": {
          "claude-opus-5-5": {"inputPerMTok": 10, "outputPerMTok": 50, "cacheReadPerMTok": 1,
                              "cacheWrite5mMultiplier": 1.25, "cacheWrite1hMultiplier": 2},
          "claude-new-1": {"inputPerMTok": 3, "outputPerMTok": 15, "cacheReadPerMTok": 0.3,
                           "cacheWrite5mMultiplier": 1.25, "cacheWrite1hMultiplier": 2}
        }}
        """, as: "prices.json")

        // When loading with the override
        let sut = try PriceTable.load(override: file)
        let bundled = try makeSUT()

        // Then opus is replaced, the new model is added, sonnet is untouched
        #expect(sut.price(for: "claude-opus-5-5")?.inputPerMTok == 10)
        #expect(sut.price(for: "claude-new-1")?.outputPerMTok == 15)
        #expect(sut.price(for: "claude-sonnet-5-5") != nil)
        #expect(sut.price(for: "claude-sonnet-5-5") == bundled.price(for: "claude-sonnet-5-5"))
    }

    @Test("Missing override file is not an error and yields the bundled table",
          .tags(.integration)) func missingOverride() throws {
        // Given a path that does not exist
        let missing = FileManager.default.temporaryDirectory
            .appending(path: "tooltrail-missing-\(UUID().uuidString).json")

        // When loading
        let sut = try PriceTable.load(override: missing)
        let bundled = try makeSUT()

        // Then the bundled table is returned (and it is not empty)
        #expect(!sut.models.isEmpty)
        #expect(sut == bundled)
    }

    @Test("Nil override yields the bundled table", .tags(.unit)) func nilOverride() throws {
        // Given no override
        // When loading
        let sut = try PriceTable.load(override: nil)
        let bundled = try makeSUT()

        // Then it equals the bundled table
        #expect(!sut.models.isEmpty)
        #expect(sut == bundled)
    }
}
