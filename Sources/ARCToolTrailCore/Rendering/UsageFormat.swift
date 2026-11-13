//
//  UsageFormat.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 13/11/2026.
//

import Foundation

/// Number formats shared by the renderers (POSIX locale, no grouping).
public enum UsageFormat {
    /// `$0.12` (two decimals), or `<$0.01` below one cent.
    public static func cost(_ usd: Double) -> String {
        guard usd >= 0.01 else {
            return "<$0.01"
        }
        return "$" + fixed(usd, digits: 2)
    }

    /// A 0–1 share as a whole percentage: `0%`, `<1%` below half a percent, else `18%`.
    public static func share(_ value: Double) -> String {
        if value <= 0 {
            return "0%"
        }
        if value < 0.005 {
            return "<1%"
        }
        return fixed(value * 100, digits: 0) + "%"
    }

    /// `780` below a thousand, `8.0k` below a million, else `1.2M`.
    public static func units(_ value: Double) -> String {
        if value < 1000 {
            return fixed(value, digits: 0)
        }
        if value < 1_000_000 {
            return fixed(value / 1000, digits: 1) + "k"
        }
        return fixed(value / 1_000_000, digits: 1) + "M"
    }

    /// Percentage points with one decimal: `0.0` at zero, `<0.1` above zero but below 0.05.
    public static func points(_ value: Double) -> String {
        value > 0 && value < 0.05 ? "<0.1" : fixed(max(0, value), digits: 1)
    }

    // MARK: - Private

    private static func fixed(_ value: Double, digits: Int) -> String {
        value.formatted(FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(digits))
            .grouping(.never)
            .locale(Locale(identifier: "en_US_POSIX")))
    }
}
