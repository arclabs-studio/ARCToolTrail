//
//  Pricing.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Turns per-model tokens into USD for one session, scaled to `cost-state` when present.
struct Pricing {
    let source: CostSource
    let sessionCost: Double?
    private let prices: PriceTable
    private let factors: [String: Double]

    init(calls: [APICall], prices: PriceTable, costState: CostState?) {
        self.prices = prices
        var priceTableCost: [String: Double] = [:]
        var hasPrice = false
        for call in calls where call.usage.total > 0 {
            if let cost = prices.cost(of: call.usage, model: call.model) {
                priceTableCost[call.model, default: 0] += cost
                hasPrice = true
            }
        }
        var factors: [String: Double] = [:]
        if let costState {
            for (model, cost) in priceTableCost where cost > 0 {
                if let actual = costState.costByModel[model] {
                    factors[model] = actual / cost
                }
            }
        }
        self.factors = factors
        if !hasPrice {
            source = .unavailable
            sessionCost = costState?.totalCostUSD
        } else if let costState {
            source = .costState
            sessionCost = costState.totalCostUSD
        } else {
            source = .priceTable
            sessionCost = priceTableCost.values.reduce(0, +)
        }
    }

    /// USD for `tokensByModel`; `nil` when no price applies to any of it.
    func cost(of tokensByModel: [String: TokenUsage]) -> Double? {
        guard source != .unavailable else {
            return nil
        }
        var total = 0.0
        var isPriced = false
        var isUnpriced = false
        for (model, usage) in tokensByModel where usage.total > 0 {
            if let cost = prices.cost(of: usage, model: model) {
                total += cost * (factors[model] ?? 1)
                isPriced = true
            } else {
                isUnpriced = true
            }
        }
        return isPriced || !isUnpriced ? total : nil
    }
}
