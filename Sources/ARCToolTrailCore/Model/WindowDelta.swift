//
//  WindowDelta.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 13/11/2026.
//

/// Percentage points of the 5-hour and 7-day rate-limit windows. `nil` when a window was not seen.
public struct WindowDelta: Hashable, Codable, Sendable {
    public let fiveHour: Double?
    public let sevenDay: Double?

    public init(fiveHour: Double?, sevenDay: Double?) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }

    /// Each known window multiplied by `factor`.
    public func scaled(by factor: Double) -> WindowDelta {
        WindowDelta(fiveHour: fiveHour.map { $0 * factor }, sevenDay: sevenDay.map { $0 * factor })
    }
}
