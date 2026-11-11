//
//  TokenUsage.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Token counts for one API call, or a share of one.
///
/// Values are `Double` because attribution splits a call's tokens among several tool uses.
public struct TokenUsage: Hashable, Codable, Sendable {
    public var input: Double
    public var output: Double
    public var cacheRead: Double
    /// Cache writes with the 5-minute TTL (also used when the transcript gives no TTL split).
    public var cacheWrite5m: Double
    /// Cache writes with the 1-hour TTL.
    public var cacheWrite1h: Double

    public init(input: Double = 0,
                output: Double = 0,
                cacheRead: Double = 0,
                cacheWrite5m: Double = 0,
                cacheWrite1h: Double = 0) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite5m = cacheWrite5m
        self.cacheWrite1h = cacheWrite1h
    }

    public static let zero = TokenUsage()

    /// Sum of every token class.
    public var total: Double {
        input + output + cacheRead + cacheWrite5m + cacheWrite1h
    }

    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(input: lhs.input + rhs.input,
                   output: lhs.output + rhs.output,
                   cacheRead: lhs.cacheRead + rhs.cacheRead,
                   cacheWrite5m: lhs.cacheWrite5m + rhs.cacheWrite5m,
                   cacheWrite1h: lhs.cacheWrite1h + rhs.cacheWrite1h)
    }

    public static func += (lhs: inout TokenUsage, rhs: TokenUsage) {
        lhs = lhs + rhs
    }

    /// Every token class multiplied by `factor`.
    public func scaled(by factor: Double) -> TokenUsage {
        TokenUsage(input: input * factor,
                   output: output * factor,
                   cacheRead: cacheRead * factor,
                   cacheWrite5m: cacheWrite5m * factor,
                   cacheWrite1h: cacheWrite1h * factor)
    }
}
