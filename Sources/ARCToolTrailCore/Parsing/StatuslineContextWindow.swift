//
//  StatuslineContextWindow.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 13/11/2026.
//

/// `context_window` of the statusline JSON.
struct StatuslineContextWindow: Decodable {
    let contextWindowSize: Int?

    enum CodingKeys: String, CodingKey {
        case contextWindowSize = "context_window_size"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contextWindowSize = try? container.decodeIfPresent(Int.self, forKey: .contextWindowSize)
    }
}
