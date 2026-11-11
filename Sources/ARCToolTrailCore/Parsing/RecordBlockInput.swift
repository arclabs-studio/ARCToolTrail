//
//  RecordBlockInput.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// The `tool_use` input fields classification needs.
struct RecordBlockInput: Decodable {
    let skill: String?
    let subagentType: String?

    enum CodingKeys: String, CodingKey {
        case skill
        case subagentType = "subagent_type"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skill = try? container.decodeIfPresent(String.self, forKey: .skill)
        subagentType = try? container.decodeIfPresent(String.self, forKey: .subagentType)
    }
}
