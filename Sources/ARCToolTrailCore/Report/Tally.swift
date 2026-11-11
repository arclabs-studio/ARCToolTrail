//
//  Tally.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Accumulates uses and attributed tokens per tool while a report is built.
struct Tally {
    struct Entry {
        var item: ReportItem
        var tokensByModel: [String: TokenUsage]
    }

    private(set) var entries: [ToolIdentity: Entry] = [:]

    var items: [Entry] {
        Array(entries.values)
    }

    /// One use of `identity` at `date`, with the tokens attributed to it.
    mutating func record(_ identity: ToolIdentity,
                         at date: Date?,
                         tokens: [String: TokenUsage],
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
        entries[identity] = entry
    }

    /// A subagent's whole cost goes to the `Agent` use that launched it; its own tool uses count
    /// without cost.
    mutating func recordSubagent(_ thread: SubagentThread, agentUses: [String: ToolIdentity]) {
        var tokens: [String: TokenUsage] = [:]
        for call in thread.calls {
            tokens[call.model, default: .zero] += call.usage
        }
        if let parent = thread.parentToolUseId.flatMap({ agentUses[$0] }) {
            // A nested launch may not be tallied yet; its use is counted when its thread is.
            var entry = entries[parent] ?? Entry(item: ReportItem(identity: parent), tokensByModel: [:])
            add(tokens, to: &entry)
            entries[parent] = entry
        } else {
            let launch = ToolUse(id: thread.agentId, name: "Agent", subagentType: thread.agentType)
            record(ToolClassifier.identity(for: launch), at: thread.calls.first?.timestamp, tokens: tokens)
        }
        for call in thread.calls {
            for toolUse in call.toolUses {
                record(ToolClassifier.identity(for: toolUse), at: call.timestamp, tokens: [:], isInSubagent: true)
            }
        }
    }

    private func add(_ tokens: [String: TokenUsage], to entry: inout Entry) {
        for (model, usage) in tokens {
            entry.tokensByModel[model, default: .zero] += usage
            entry.item.attributedTokens += usage
        }
    }
}
