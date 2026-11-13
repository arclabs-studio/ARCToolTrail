//
//  StatuslineRateLimits.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 13/11/2026.
//

/// `rate_limits` of the statusline JSON. A window that fails to decode is `nil`.
struct StatuslineRateLimits: Decodable {
    let fiveHour: StatuslineWindow?
    let sevenDay: StatuslineWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try? container.decodeIfPresent(StatuslineWindow.self, forKey: .fiveHour)
        sevenDay = try? container.decodeIfPresent(StatuslineWindow.self, forKey: .sevenDay)
    }
}
