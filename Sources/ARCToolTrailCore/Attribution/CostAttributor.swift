//
//  CostAttributor.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Approximate per-tool token attribution for one thread of calls.
///
/// For a call `i` that emits `n > 0` tool uses, each tool use receives:
/// - `output / n` of call `i` (billed at call `i`'s model), and
/// - `(input + cacheWrite5m + cacheWrite1h) / n` of call `i + 1`, if it exists (billed at call
///   `i + 1`'s model): the new context the tool results added.
///
/// Cache reads are never attributed (they are the shared context). Calls without tool uses
/// attribute nothing. Every token is attributed at most once, so the attributed total never exceeds
/// the thread total.
///
/// Context weight, from the added tokens `a` (raw, not weighted) and `compactions` (index of the first
/// call after each `compact_boundary`):
/// - `contextCarry = a × (later calls after i + 1 and before the next compaction)`: roughly how many
///   tokens the result made the model re-read as cache reads.
/// - `liveContextTokens = a` when call `i + 1` comes at or after the last compaction, else 0.
public enum CostAttributor {
    public static func attribute(_ calls: [APICall], compactions: [Int] = []) -> [ToolUseAttribution] {
        let lastCompaction = compactions.max() ?? 0
        return calls.indices.flatMap { index -> [ToolUseAttribution] in
            let call = calls[index]
            guard !call.toolUses.isEmpty else {
                return []
            }
            let share = 1 / Double(call.toolUses.count)
            var tokens: [String: TokenUsage] = [call.model: TokenUsage(output: call.usage.output * share)]
            var carry = 0.0
            var live = 0.0
            let addedAt = index + 1
            if addedAt < calls.count {
                let next = calls[addedAt]
                let added = TokenUsage(input: next.usage.input,
                                       cacheWrite5m: next.usage.cacheWrite5m,
                                       cacheWrite1h: next.usage.cacheWrite1h)
                    .scaled(by: share)
                tokens[next.model, default: .zero] += added
                let end = compactions.first { $0 > addedAt } ?? calls.count
                carry = added.total * Double(max(0, end - addedAt - 1))
                live = addedAt >= lastCompaction ? added.total : 0
            }
            return call.toolUses.map {
                ToolUseAttribution(toolUse: $0,
                                   tokensByModel: tokens,
                                   timestamp: call.timestamp,
                                   contextCarry: carry,
                                   liveContextTokens: live)
            }
        }
    }
}
