//
//  ReportBuilder.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Builds a `SessionReport` from a parsed session.
///
/// - Main-thread tool uses are attributed with `CostAttributor`, with the session's compactions.
/// - A subagent's tokens (every token of its calls except cache reads) go to the `.subagent` item of
///   the `Agent` tool use that launched it (matched by `parentToolUseId`; unmatched threads use
///   `agentType`, default `general-purpose`, and count one use). Its cache reads go to that item's
///   `contextCarry`, as the main thread's cache reads are never attributed either.
/// - Tool uses inside subagents count towards `uses` and `usesInSubagents` of their own item but
///   carry no cost (it is already in the subagent item).
/// - USD = price-table cost per model. With a `cost-state`, each model's figures are scaled by
///   `costState.costByModel[model] / priceTableCost(all calls of that model)`.
/// - `sessionCostUSD` = `costState.totalCostUSD`, else the price-table cost of all calls.
/// - `cleanup` = inventory servers and plugins that no item uses.
/// - Weighted units (``TokenWeights``): `sessionWeighted` covers every call; each item's
///   `sessionShare = weighted / sessionWeighted`. With a `WindowBaseline`, each item's
///   `windowPoints = windowDelta × sessionShare` and `liveContextShare = liveContextTokens /
///   contextWindowSize`.
public struct ReportBuilder: Sendable {
    public let prices: PriceTable

    public init(prices: PriceTable) {
        self.prices = prices
    }

    public func build(_ session: ParsedSession,
                      inventory: ConfigInventory? = nil,
                      windows: WindowBaseline? = nil,
                      now: Date = .now) -> SessionReport {
        var tally = Tally()
        for attribution in CostAttributor.attribute(session.calls, compactions: session.compactions) {
            tally.record(attribution)
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
        let sessionTokens = allCalls.reduce(TokenUsage.zero) { $0 + $1.usage }
        let sessionWeighted = allCalls.reduce(0) {
            $0 + TokenWeights.units(of: $1.usage, model: $1.model, prices: prices)
        }
        let windowDelta = windows?.delta
        let contextWindowSize = windows?.contextWindowSize
        let measured = tally.items.map { entry in
            var item = entry.item
            item.estimatedCostUSD = pricing.cost(of: entry.tokensByModel)
            item.weighted = TokenWeights.units(of: entry.tokensByModel, prices: prices)
            item.sessionShare = sessionWeighted > 0 ? item.weighted / sessionWeighted : 0
            item.weightedPerUse = Self.perUse(item)
            item.windowPoints = windowDelta?.scaled(by: item.sessionShare)
            item.liveContextShare = contextWindowSize
                .flatMap { $0 > 0 ? item.liveContextTokens / Double($0) : nil }
            return item
        }
        let items = measured.sorted(by: Self.reportOrder)

        let attributed = pricing.source == .unavailable ? nil : items.compactMap(\.estimatedCostUSD).reduce(0, +)
        return SessionReport(sessionId: session.sessionId,
                             generatedAt: now,
                             items: items,
                             sessionCostUSD: pricing.sessionCost,
                             attributedCostUSD: attributed,
                             costSource: pricing.source,
                             cleanup: Self.cleanup(items: items, inventory: inventory),
                             sessionTokens: sessionTokens,
                             sessionWeighted: sessionWeighted,
                             attributedWeighted: items.reduce(0) { $0 + $1.weighted },
                             windowDelta: windowDelta,
                             contextWindowSize: contextWindowSize)
    }

    // MARK: - Private

    /// Category, then weighted units (highest first), then name.
    private static func reportOrder(_ lhs: ReportItem, _ rhs: ReportItem) -> Bool {
        if lhs.identity.category != rhs.identity.category {
            return lhs.identity.category < rhs.identity.category
        }
        if lhs.weighted != rhs.weighted {
            return lhs.weighted > rhs.weighted
        }
        return lhs.identity.name < rhs.identity.name
    }

    /// `weighted` over the uses made outside subagents, or over every use when all were inside one.
    private static func perUse(_ item: ReportItem) -> Double {
        let outside = item.uses - item.usesInSubagents
        let divisor = outside > 0 ? outside : item.uses
        return divisor > 0 ? item.weighted / Double(divisor) : 0
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
