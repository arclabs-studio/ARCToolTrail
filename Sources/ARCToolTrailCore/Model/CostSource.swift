//
//  CostSource.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Where the USD figures of a report come from.
public enum CostSource: String, Codable, Sendable {
    /// Price table, scaled per model to Claude Code's `cost-state` record.
    case costState
    /// Price table only (no `cost-state` record yet).
    case priceTable
    /// No price known for any model in the session: tokens only.
    case unavailable
}
