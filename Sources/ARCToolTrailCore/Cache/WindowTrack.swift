//
//  WindowTrack.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 13/11/2026.
//

import Foundation

/// How many percentage points of one rate-limit window (5 h or 7 d) were used during a session.
///
/// A segment runs while `resets_at` stays the same (within 60 s). When a later `resets_at` arrives the
/// window rolled over: the segment's growth is banked in `closedPoints` and a new segment starts at 0,
/// because the new window began empty. A sample with an earlier `resets_at` is stale and ignored.
/// The figure includes every session sharing the account, so it is an upper bound for this one.
public struct WindowTrack: Hashable, Codable, Sendable {
    /// Growth of the finished segments.
    public private(set) var closedPoints: Double
    /// `used_percentage` at the start of the current segment.
    public private(set) var start: Double
    /// Highest `used_percentage` seen in the current segment.
    public private(set) var latest: Double
    /// `resets_at` of the current segment.
    public private(set) var resetsAt: Date

    public init(first sample: WindowSample) {
        closedPoints = 0
        start = sample.usedPercentage
        latest = sample.usedPercentage
        resetsAt = sample.resetsAt
    }

    /// Points used since the first sample.
    public var points: Double {
        closedPoints + max(0, latest - start)
    }

    public mutating func record(_ sample: WindowSample) {
        let shift = sample.resetsAt.timeIntervalSince(resetsAt)
        if abs(shift) <= Self.jitter {
            latest = max(latest, sample.usedPercentage)
        } else if shift > 0 {
            closedPoints += max(0, latest - start)
            start = 0
            latest = sample.usedPercentage
            resetsAt = sample.resetsAt
        }
    }

    // MARK: - Private

    /// Tolerance for `resets_at` values that describe the same window.
    private static let jitter: TimeInterval = 60
}
