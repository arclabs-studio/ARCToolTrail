//
//  ToolUse.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// One `tool_use` block emitted by the model, reduced to what classification needs.
public struct ToolUse: Hashable, Codable, Sendable {
    /// The `tool_use` id (`toolu_...`).
    public let id: String
    /// The tool name as sent by the model (`Bash`, `Skill`, `mcp__firecrawl__firecrawl_search`, ...).
    public let name: String
    /// `input.skill` for the `Skill` tool.
    public let skill: String?
    /// `input.subagent_type` for the `Agent` tool.
    public let subagentType: String?

    public init(id: String, name: String, skill: String? = nil, subagentType: String? = nil) {
        self.id = id
        self.name = name
        self.skill = skill
        self.subagentType = subagentType
    }
}
