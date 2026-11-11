//
//  ToolCategory.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// The group a tool invocation belongs to in a session report.
public enum ToolCategory: String, Codable, Sendable, CaseIterable, Comparable {
    /// A skill loaded through the `Skill` tool that does not come from a plugin.
    case skill
    /// A tool exposed by an MCP server configured outside any plugin (including claude.ai connectors).
    case mcp
    /// A skill or MCP tool that ships inside a plugin.
    case plugin
    /// A subagent launched through the `Agent` tool.
    case subagent
    /// Any other Claude Code tool (`Bash`, `Read`, `Edit`, ...).
    case builtin

    /// Human-readable section title.
    public var title: String {
        switch self {
        case .skill: "Skills"
        case .mcp: "MCP"
        case .plugin: "Plugins"
        case .subagent: "Subagents"
        case .builtin: "Built-in"
        }
    }

    public static func < (lhs: ToolCategory, rhs: ToolCategory) -> Bool {
        let order = allCases
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}
