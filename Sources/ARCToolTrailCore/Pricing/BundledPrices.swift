//
//  BundledPrices.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// The price table compiled into the binary, in the same JSON shape as the override file.
///
/// It lives in source rather than in a resource bundle so `tooltrail` is a single file:
/// a binary copied without its `.bundle` would otherwise crash on `Bundle.module`.
/// When you change a price, update `asOf` and `source` in the same commit.
enum BundledPrices {
    static let json = #"""
    {
      "asOf": "2026-11-03",
      "source": "Anthropic API list prices, USD/MTok. 5.5 models and Haiku 4.5 checked vs cost-state, 2026-11-11.",
      "models": {
        "claude-fable-5-2": {
          "inputPerMTok": 8,
          "outputPerMTok": 40,
          "cacheReadPerMTok": 0.2,
          "cacheWrite5mMultiplier": 1.25,
          "cacheWrite1hMultiplier": 2
        },
        "claude-haiku-4-5": {
          "inputPerMTok": 1,
          "outputPerMTok": 5,
          "cacheReadPerMTok": 0.1,
          "cacheWrite5mMultiplier": 1.25,
          "cacheWrite1hMultiplier": 2
        },
        "claude-haiku-5-5": {
          "inputPerMTok": 0.1,
          "outputPerMTok": 0.5,
          "cacheReadPerMTok": 0.01,
          "cacheWrite5mMultiplier": 1.25,
          "cacheWrite1hMultiplier": 2
        },
        "claude-opus-5-5": {
          "inputPerMTok": 4,
          "outputPerMTok": 20,
          "cacheReadPerMTok": 0.2,
          "cacheWrite5mMultiplier": 1.25,
          "cacheWrite1hMultiplier": 2
        },
        "claude-sonnet-5-5": {
          "inputPerMTok": 2,
          "outputPerMTok": 10,
          "cacheReadPerMTok": 0.1,
          "cacheWrite5mMultiplier": 1.25,
          "cacheWrite1hMultiplier": 2
        }
      }
    }
    """#
}
