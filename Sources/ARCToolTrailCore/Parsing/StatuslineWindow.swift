//
//  StatuslineWindow.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 13/11/2026.
//

import Foundation

/// One `rate_limits` window; `sample` is `nil` unless both fields parse.
struct StatuslineWindow: Decodable {
    let sample: WindowSample?

    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt = "resets_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let used = try? container.decodeIfPresent(Double.self, forKey: .usedPercentage)
        let resets = (try? container.decodeIfPresent(Double.self, forKey: .resetsAt))
            .map { Date(timeIntervalSince1970: $0) }
            ?? (try? container.decodeIfPresent(String.self, forKey: .resetsAt)).flatMap(Self.date(from:))
        guard let used, let resets else {
            sample = nil
            return
        }
        sample = WindowSample(usedPercentage: used, resetsAt: resets)
    }

    private static func date(from text: String) -> Date? {
        if let seconds = Double(text) {
            return Date(timeIntervalSince1970: seconds)
        }
        return (try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
            ?? (try? Date(text, strategy: Date.ISO8601FormatStyle()))
    }
}
