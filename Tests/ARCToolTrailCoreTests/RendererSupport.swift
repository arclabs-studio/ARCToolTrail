//
//  RendererSupport.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation

/// Hand-built reports for the renderer suites.
enum ReportFactory {
    static let generatedAt = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z

    static func item(_ name: String,
                     _ category: ToolCategory,
                     uses: Int,
                     cost: Double?,
                     plugin: String? = nil,
                     server: String? = nil,
                     isConnector: Bool = false) -> ReportItem {
        ReportItem(identity: ToolIdentity(category: category, name: name, plugin: plugin, server: server,
                                          isConnector: isConnector),
                   uses: uses,
                   usesInSubagents: 0,
                   firstUse: generatedAt,
                   lastUse: generatedAt,
                   attributedTokens: TokenUsage(input: 1, output: 2),
                   estimatedCostUSD: cost)
    }

    static func report(items: [ReportItem],
                       session: Double? = 0.2,
                       attributed: Double? = 0.1,
                       source: CostSource = .costState,
                       cleanup: [CleanupCandidate] = []) -> SessionReport {
        SessionReport(sessionId: "sess-123",
                      generatedAt: generatedAt,
                      items: items,
                      sessionCostUSD: session,
                      attributedCostUSD: attributed,
                      costSource: source,
                      cleanup: cleanup)
    }
}
