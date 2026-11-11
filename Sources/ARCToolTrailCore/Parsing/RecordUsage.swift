//
//  RecordUsage.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// `message.usage` of an assistant record.
struct RecordUsage: Decodable {
    let inputTokens: Double?
    let outputTokens: Double?
    let cacheReadInputTokens: Double?
    let cacheCreationInputTokens: Double?
    let cacheCreation: RecordCacheCreation?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheCreation = "cache_creation"
    }

    /// Without a TTL split, every cache write counts as a 5-minute write.
    var tokenUsage: TokenUsage {
        let split5m = cacheCreation?.ephemeral5mInputTokens
        let split1h = cacheCreation?.ephemeral1hInputTokens
        let hasSplit = split5m != nil || split1h != nil
        return TokenUsage(input: inputTokens ?? 0,
                          output: outputTokens ?? 0,
                          cacheRead: cacheReadInputTokens ?? 0,
                          cacheWrite5m: hasSplit ? (split5m ?? 0) : (cacheCreationInputTokens ?? 0),
                          cacheWrite1h: hasSplit ? (split1h ?? 0) : 0)
    }
}
