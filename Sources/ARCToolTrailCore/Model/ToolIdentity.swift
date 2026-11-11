//
//  ToolIdentity.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Identifies one reportable tool: the unit counts and costs are aggregated by.
public struct ToolIdentity: Hashable, Codable, Sendable {
    /// Report group.
    public let category: ToolCategory
    /// Display name, unique within the category (e.g. `firecrawl`, `plugin-authoring`, `Explore`, `Bash`).
    public let name: String
    /// Plugin that provides the tool, when known.
    public let plugin: String?
    /// MCP server name, for MCP tools.
    public let server: String?
    /// `true` for claude.ai connectors (`mcp__claude_ai_*`).
    public let isConnector: Bool

    public init(category: ToolCategory,
                name: String,
                plugin: String? = nil,
                server: String? = nil,
                isConnector: Bool = false) {
        self.category = category
        self.name = name
        self.plugin = plugin
        self.server = server
        self.isConnector = isConnector
    }
}
