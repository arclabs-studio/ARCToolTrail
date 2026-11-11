//
//  ToolClassifier.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Maps a raw tool use to the report item it counts towards.
///
/// Rules:
/// - `Skill` with `input.skill = "name"` → `.skill`, name `name`.
/// - `Skill` with `input.skill = "plugin:name"` → `.plugin`, name `plugin:name`, plugin `plugin`.
/// - `mcp__plugin_<plugin>_<server>__<tool>` → `.plugin`, name `<plugin>:<server>`, plugin + server set.
/// - `mcp__<server>__<tool>` → `.mcp`, name `<server>`, server set; `isConnector` when `<server>` starts with
/// `claude_ai_`.
/// - `Agent` → `.subagent`, name `input.subagent_type` (default `general-purpose`);
///   a `plugin:agent` type also sets plugin.
/// - Anything else → `.builtin`, name = tool name.
public enum ToolClassifier {
    private static let connectorPrefix = "claude_ai_"
    private static let pluginServerPrefix = "plugin_"
    private static let defaultSubagent = "general-purpose"

    public static func identity(for toolUse: ToolUse) -> ToolIdentity {
        switch toolUse.name {
        case "Skill":
            skillIdentity(toolUse.skill ?? toolUse.name)
        case "Agent":
            subagentIdentity(toolUse.subagentType ?? defaultSubagent)
        default:
            mcpIdentity(toolUse.name) ?? ToolIdentity(category: .builtin, name: toolUse.name)
        }
    }

    private static func skillIdentity(_ skill: String) -> ToolIdentity {
        guard let plugin = pluginPrefix(of: skill) else {
            return ToolIdentity(category: .skill, name: skill)
        }
        return ToolIdentity(category: .plugin, name: skill, plugin: plugin)
    }

    private static func subagentIdentity(_ type: String) -> ToolIdentity {
        ToolIdentity(category: .subagent, name: type, plugin: pluginPrefix(of: type))
    }

    /// `mcp__<server>__<tool>`; `nil` for anything else.
    private static func mcpIdentity(_ name: String) -> ToolIdentity? {
        let parts = name.split(separator: "__", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "mcp", !parts[1].isEmpty else {
            return nil
        }
        let server = String(parts[1])
        if server.hasPrefix(pluginServerPrefix) {
            let rest = server.dropFirst(pluginServerPrefix.count)
            if let split = rest.firstIndex(of: "_") {
                let plugin = String(rest[..<split])
                let pluginServer = String(rest[rest.index(after: split)...])
                if !plugin.isEmpty, !pluginServer.isEmpty {
                    return ToolIdentity(category: .plugin,
                                        name: "\(plugin):\(pluginServer)",
                                        plugin: plugin,
                                        server: pluginServer)
                }
            }
        }
        return ToolIdentity(category: .mcp,
                            name: server,
                            server: server,
                            isConnector: server.hasPrefix(connectorPrefix))
    }

    /// `plugin` for `plugin:name`, else `nil`.
    private static func pluginPrefix(of value: String) -> String? {
        guard let colon = value.firstIndex(of: ":"), colon != value.startIndex else {
            return nil
        }
        return String(value[..<colon])
    }
}
