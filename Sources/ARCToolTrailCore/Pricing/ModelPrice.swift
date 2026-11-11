//
//  ModelPrice.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Price of one model in USD per million tokens.
public struct ModelPrice: Hashable, Codable, Sendable {
    public let inputPerMTok: Double
    public let outputPerMTok: Double
    public let cacheReadPerMTok: Double
    /// Cache-write price as a multiple of input (Anthropic: 1.25 for the 5-minute TTL).
    public let cacheWrite5mMultiplier: Double
    /// Cache-write price as a multiple of input (Anthropic: 2.0 for the 1-hour TTL).
    public let cacheWrite1hMultiplier: Double

    public init(inputPerMTok: Double,
                outputPerMTok: Double,
                cacheReadPerMTok: Double,
                cacheWrite5mMultiplier: Double = 1.25,
                cacheWrite1hMultiplier: Double = 2.0) {
        self.inputPerMTok = inputPerMTok
        self.outputPerMTok = outputPerMTok
        self.cacheReadPerMTok = cacheReadPerMTok
        self.cacheWrite5mMultiplier = cacheWrite5mMultiplier
        self.cacheWrite1hMultiplier = cacheWrite1hMultiplier
    }
}
