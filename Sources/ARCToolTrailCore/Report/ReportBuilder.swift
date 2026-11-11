//
//  ReportBuilder.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Builds a `SessionReport` from a parsed session.
///
/// - Main-thread tool uses are attributed with `CostAttributor`.
/// - A subagent's whole cost (every token of its calls) goes to the `.subagent` item of the `Agent`
///   tool use that launched it (matched by `parentToolUseId`; unmatched threads use `agentType`,
///   default `general-purpose`, and count one use).
/// - Tool uses inside subagents count towards `uses` and `usesInSubagents` of their own item but
///   carry no cost (it is already in the subagent item).
/// - USD = price-table cost per model. With a `cost-state`, each model's figures are scaled by
///   `costState.costByModel[model] / priceTableCost(all calls of that model)`.
/// - `sessionCostUSD` = `costState.totalCostUSD`, else the price-table cost of all calls.
/// - `cleanup` = inventory servers and plugins that no item uses.
public struct ReportBuilder: Sendable {
    public let prices: PriceTable

    public init(prices: PriceTable) {
        self.prices = prices
    }

    public func build(_ session: ParsedSession,
                      inventory: ConfigInventory? = nil,
                      now: Date = .now) -> SessionReport {
        var tally = Tally()
        for attribution in CostAttributor.attribute(session.calls) {
            tally.record(ToolClassifier.identity(for: attribution.toolUse),
                         at: attribution.timestamp,
                         tokens: attribution.tokensByModel)
        }
        let agentUses = Dictionary((session.calls + session.subagents.flatMap(\.calls))
            .flatMap(\.toolUses)
            .filter { $0.name == "Agent" }
            .map { ($0.id, ToolClassifier.identity(for: $0)) }) { first, _ in first }
        for thread in session.subagents {
            tally.recordSubagent(thread, agentUses: agentUses)
        }

        let allCalls = session.calls + session.subagents.flatMap(\.calls)
        let pricing = Pricing(calls: allCalls, prices: prices, costState: session.costState)
        let priced = tally.items.map { entry in
            var item = entry.item
            item.estimatedCostUSD = pricing.cost(of: entry.tokensByModel)
            return item
        }
        let items = priced.sorted(by: Self.reportOrder)

        let attributed = pricing.source == .unavailable ? nil : items.compactMap(\.estimatedCostUSD).reduce(0, +)
        return SessionReport(sessionId: session.sessionId,
                             generatedAt: now,
                             items: items,
                             sessionCostUSD: pricing.sessionCost,
                             attributedCostUSD: attributed,
                             costSource: pricing.source,
                             cleanup: Self.cleanup(items: items, inventory: inventory))
    }

    // MARK: - Private

    /// Category, then estimated cost (highest first, unknown last), then name.
    private static func reportOrder(_ lhs: ReportItem, _ rhs: ReportItem) -> Bool {
        if lhs.identity.category != rhs.identity.category {
            return lhs.identity.category < rhs.identity.category
        }
        let lhsCost = lhs.estimatedCostUSD ?? -1
        let rhsCost = rhs.estimatedCostUSD ?? -1
        if lhsCost != rhsCost {
            return lhsCost > rhsCost
        }
        return lhs.identity.name < rhs.identity.name
    }

    private static func cleanup(items: [ReportItem], inventory: ConfigInventory?) -> [CleanupCandidate] {
        guard let inventory else {
            return []
        }
        let usedServers = Set(items.compactMap(\.identity.server))
        let usedPlugins = Set(items.compactMap(\.identity.plugin))
        let servers = inventory.mcpServers.subtracting(usedServers)
            .sorted()
            .map { CleanupCandidate(kind: .mcpServer, name: $0) }
        let plugins = inventory.plugins.subtracting(usedPlugins)
            .sorted()
            .map { CleanupCandidate(kind: .plugin, name: $0) }
        return servers + plugins
    }
}
