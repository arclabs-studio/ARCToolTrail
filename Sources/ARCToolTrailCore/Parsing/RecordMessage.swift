//
//  RecordMessage.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// `message` of an assistant record.
struct RecordMessage: Decodable {
    let id: String
    let model: String?
    let usage: RecordUsage?
    let content: [RecordBlock]

    enum CodingKeys: String, CodingKey {
        case id, model, usage, content
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        usage = try? container.decodeIfPresent(RecordUsage.self, forKey: .usage)
        // User records carry a plain string here; only block arrays matter.
        content = (try? container.decodeIfPresent([RecordBlock].self, forKey: .content)) ?? []
    }
}
