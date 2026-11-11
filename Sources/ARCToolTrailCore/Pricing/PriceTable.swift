//
//  PriceTable.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Model prices used to turn tokens into an approximate USD cost.
///
/// The bundled table (``BundledPrices``) can be overridden per model by a JSON file of the same shape
/// (default `~/.config/tooltrail/prices.json`). Model ids are matched after normalisation:
/// an `anthropic.` prefix, a `[1m]` suffix and a `-YYYYMMDD` date suffix are ignored.
public struct PriceTable: Hashable, Codable, Sendable {
    public let models: [String: ModelPrice]

    public init(models: [String: ModelPrice]) {
        self.models = models
    }

    /// The table compiled into the package (``BundledPrices``).
    public static func bundled() throws -> PriceTable {
        try JSONDecoder().decode(PriceTable.self, from: Data(BundledPrices.json.utf8))
    }

    /// The bundled table with every model in `override` replacing or adding to it.
    /// A missing override file is not an error.
    public static func load(override: URL?) throws -> PriceTable {
        let base = try bundled()
        guard let override, FileManager.default.fileExists(atPath: override.path(percentEncoded: false)) else {
            return base
        }
        let extra = try JSONDecoder().decode(PriceTable.self, from: Data(contentsOf: override))
        return PriceTable(models: base.models.merging(extra.models) { _, new in new })
    }

    public func price(for model: String) -> ModelPrice? {
        models[model] ?? models[Self.normalize(model)]
    }

    /// USD cost of `usage` on `model`, or `nil` when the model has no price.
    public func cost(of usage: TokenUsage, model: String) -> Double? {
        guard let price = price(for: model) else {
            return nil
        }
        let perToken = 1 / 1_000_000.0
        return (usage.input * price.inputPerMTok
            + usage.output * price.outputPerMTok
            + usage.cacheRead * price.cacheReadPerMTok
            + usage.cacheWrite5m * price.inputPerMTok * price.cacheWrite5mMultiplier
            + usage.cacheWrite1h * price.inputPerMTok * price.cacheWrite1hMultiplier) * perToken
    }

    /// Drops an `anthropic.` prefix, a `[1m]` suffix and a `-YYYYMMDD` date suffix.
    static func normalize(_ model: String) -> String {
        var id = Substring(model)
        if id.hasPrefix("anthropic.") {
            id = id.dropFirst("anthropic.".count)
        }
        if id.hasSuffix("[1m]") {
            id = id.dropLast("[1m]".count)
        }
        if let match = id.wholeMatch(of: /(.+)-\d{8}/) {
            id = match.1
        }
        return String(id)
    }
}
