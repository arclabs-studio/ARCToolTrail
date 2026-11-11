//
//  RecordBlock.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// One `message.content` block.
struct RecordBlock: Decodable {
    let type: String?
    let id: String?
    let name: String?
    let input: RecordBlockInput?

    var toolUse: ToolUse? {
        guard type == "tool_use", let id, let name else {
            return nil
        }
        return ToolUse(id: id, name: name, skill: input?.skill, subagentType: input?.subagentType)
    }
}
