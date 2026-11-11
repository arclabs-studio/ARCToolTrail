//
//  CostState.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// The last `cost-state` record of a session: Claude Code's own cost accounting.
public struct CostState: Hashable, Codable, Sendable {
    /// Whole-session cost, subagents included.
    public let totalCostUSD: Double
    /// Cost per model id.
    public let costByModel: [String: Double]

    public init(totalCostUSD: Double, costByModel: [String: Double]) {
        self.totalCostUSD = totalCostUSD
        self.costByModel = costByModel
    }
}
