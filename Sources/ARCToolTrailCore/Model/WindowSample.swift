//
//  WindowSample.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 13/11/2026.
//

import Foundation

/// One reading of a rate-limit window from the statusline JSON.
public struct WindowSample: Hashable, Codable, Sendable {
    /// `used_percentage` of the window, 0–100.
    public let usedPercentage: Double
    /// When the window resets.
    public let resetsAt: Date

    public init(usedPercentage: Double, resetsAt: Date) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }
}
