//
//  RecordCacheCreation.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// `usage.cache_creation`: the cache-write TTL split.
struct RecordCacheCreation: Decodable {
    let ephemeral5mInputTokens: Double?
    let ephemeral1hInputTokens: Double?

    enum CodingKeys: String, CodingKey {
        case ephemeral5mInputTokens = "ephemeral_5m_input_tokens"
        case ephemeral1hInputTokens = "ephemeral_1h_input_tokens"
    }
}
