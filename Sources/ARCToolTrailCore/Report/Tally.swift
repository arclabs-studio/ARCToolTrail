//
//  Tally.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Accumulates uses, attributed tokens and context weight per tool while a report is built.
struct Tally {
    struct Entry {
        var item: ReportItem
        var tokensByModel: [String: TokenUsage]
    }

    private(set) var entries: [ToolIdentity: Entry] = [:]

    var items: [Entry] {
        Array(entries.values)
    }

    /// One main-thread use, with its attributed tokens and context weight.
    mutating func record(_ attribution: ToolUseAttribution) {
        record(ToolClassifier.identity(for: attribution.toolUse),
               at: attribution.timestamp,
               tokens: attribution.tokensByModel,
               contextCarry: attribution.contextCarry,
               liveContextTokens: attribution.liveContextTokens)
    }

    /// A subagent's tokens go to the `Agent` use that launched it, without cache reads, like the main
    /// thread; its cache reads count as that use's context carry. Its own tool uses count without cost.
    mutating func recordSubagent(_ thread: SubagentThread, agentUses: [String: ToolIdentity]) {
        var tokens: [String: TokenUsage] = [:]
        var cacheRead = 0.0
        for call in thread.calls {
            var usage = call.usage
            cacheRead += usage.cacheRead
            usage.cacheRead = 0
            tokens[call.model, default: .zero] += usage
        }
        if let parent = thread.parentToolUseId.flatMap({ agentUses[$0] }) {
            // A nested launch may not be tallied yet; its use is counted when its thread is.
            var entry = entries[parent] ?? Entry(item: ReportItem(identity: parent), tokensByModel: [:])
            add(tokens, to: &entry)
            entry.item.contextCarry += cacheRead
            entries[parent] = entry
        } else {
            let launch = ToolUse(id: thread.agentId, name: "Agent", subagentType: thread.agentType)
            record(ToolClassifier.identity(for: launch),
                   at: thread.calls.first?.timestamp,
                   tokens: tokens,
                   contextCarry: cacheRead)
        }
        for call in thread.calls {
            for toolUse in call.toolUses {
                record(ToolClassifier.identity(for: toolUse), at: call.timestamp, tokens: [:], isInSubagent: true)
            }
        }
    }

    // MARK: - Private

    private mutating func record(_ identity: ToolIdentity,
                                 at date: Date?,
                                 tokens: [String: TokenUsage],
                                 contextCarry: Double = 0,
                                 liveContextTokens: Double = 0,
                                 isInSubagent: Bool = false) {
        var entry = entries[identity] ?? Entry(item: ReportItem(identity: identity), tokensByModel: [:])
        entry.item.uses += 1
        if isInSubagent {
            entry.item.usesInSubagents += 1
        }
        if let date {
            entry.item.firstUse = min(entry.item.firstUse ?? date, date)
            entry.item.lastUse = max(entry.item.lastUse ?? date, date)
        }
        add(tokens, to: &entry)
        entry.item.contextCarry += contextCarry
        entry.item.liveContextTokens += liveContextTokens
        entries[identity] = entry
    }

    private func add(_ tokens: [String: TokenUsage], to entry: inout Entry) {
        for (model, usage) in tokens {
            entry.tokensByModel[model, default: .zero] += usage
            entry.item.attributedTokens += usage
        }
    }
}
