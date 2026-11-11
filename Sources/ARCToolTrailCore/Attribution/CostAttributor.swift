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
public enum CostAttributor {
    public static func attribute(_ calls: [APICall]) -> [ToolUseAttribution] {
        calls.indices.flatMap { index -> [ToolUseAttribution] in
            let call = calls[index]
            guard !call.toolUses.isEmpty else {
                return []
            }
            let share = 1 / Double(call.toolUses.count)
            var tokens: [String: TokenUsage] = [call.model: TokenUsage(output: call.usage.output * share)]
            if index + 1 < calls.count {
                let next = calls[index + 1]
                let added = TokenUsage(input: next.usage.input,
                                       cacheWrite5m: next.usage.cacheWrite5m,
                                       cacheWrite1h: next.usage.cacheWrite1h)
                tokens[next.model, default: .zero] += added.scaled(by: share)
            }
            return call.toolUses
                .map { ToolUseAttribution(toolUse: $0, tokensByModel: tokens, timestamp: call.timestamp) }
        }
    }
}
