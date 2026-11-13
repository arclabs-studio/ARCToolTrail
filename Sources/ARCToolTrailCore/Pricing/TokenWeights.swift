//
//  TokenWeights.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 13/11/2026.
//

/// Turns tokens into "weighted units": 1 unit = 1 input token of the same model.
///
/// Each token class is weighted by its list price relative to input, so the units approximate how
/// much a tool weighs on a usage limit without showing dollars. This is a proxy: Anthropic does not
/// publish how plan limits weight token types.
///
/// `units = input + output × (output/input price) + cacheRead × (cache-read/input price)
///   + cacheWrite5m × 5-minute multiplier + cacheWrite1h × 1-hour multiplier`.
/// A model without a price uses the standard ratios: output 5, cache read 0.1, writes 1.25 and 2.
public enum TokenWeights {
    public static func units(of usage: TokenUsage, model: String, prices: PriceTable) -> Double {
        let ratios = Ratios(prices.price(for: model))
        return usage.input
            + usage.output * ratios.output
            + usage.cacheRead * ratios.cacheRead
            + usage.cacheWrite5m * ratios.cacheWrite5m
            + usage.cacheWrite1h * ratios.cacheWrite1h
    }

    /// Sum of ``units(of:model:prices:)`` over every model.
    public static func units(of tokensByModel: [String: TokenUsage], prices: PriceTable) -> Double {
        tokensByModel.reduce(0) { $0 + units(of: $1.value, model: $1.key, prices: prices) }
    }

    // MARK: - Private

    private struct Ratios {
        let output: Double
        let cacheRead: Double
        let cacheWrite5m: Double
        let cacheWrite1h: Double

        init(_ price: ModelPrice?) {
            guard let price, price.inputPerMTok > 0 else {
                output = 5
                cacheRead = 0.1
                cacheWrite5m = 1.25
                cacheWrite1h = 2
                return
            }
            output = price.outputPerMTok / price.inputPerMTok
            cacheRead = price.cacheReadPerMTok / price.inputPerMTok
            cacheWrite5m = price.cacheWrite5mMultiplier
            cacheWrite1h = price.cacheWrite1hMultiplier
        }
    }
}
