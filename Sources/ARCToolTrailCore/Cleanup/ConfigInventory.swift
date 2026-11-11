//
//  ConfigInventory.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// MCP servers and plugins available to a session, to find the ones never used.
public struct ConfigInventory: Hashable, Codable, Sendable {
    public let mcpServers: Set<String>
    /// Plugin names without the `@marketplace` suffix.
    public let plugins: Set<String>

    public init(mcpServers: Set<String>, plugins: Set<String>) {
        self.mcpServers = mcpServers
        self.plugins = plugins
    }

    /// Reads the inventory from Claude Code's config files. Missing files are skipped.
    ///
    /// - `claudeJSON` (`~/.claude.json`): keys of top-level `mcpServers` and of
    ///   `projects[projectPath].mcpServers`.
    /// - `settingsJSON` (`~/.claude/settings.json`): keys of `enabledPlugins` whose value is `true`,
    ///   with the `@marketplace` suffix removed.
    /// - `loadedList`: `{"mcpServers": [..], "plugins": [..]}` written by the mod with what the
    ///   session actually loaded (claude.ai connectors included); merged into the result.
    public static func load(claudeJSON: URL?,
                            settingsJSON: URL?,
                            projectPath: String?,
                            loadedList: URL?) throws -> ConfigInventory {
        var servers = Set<String>()
        var plugins = Set<String>()
        if let claude = try decode(ClaudeJSON.self, at: claudeJSON) {
            servers.formUnion(claude.mcpServers.map { Array($0.keys) } ?? [])
            if let projectPath, let project = claude.projects?[projectPath] {
                servers.formUnion(project.mcpServers.map { Array($0.keys) } ?? [])
            }
        }
        if let settings = try decode(Settings.self, at: settingsJSON) {
            let enabled = (settings.enabledPlugins ?? [:]).filter(\.value).keys
            plugins.formUnion(enabled.map(pluginName(_:)))
        }
        if let loaded = try decode(LoadedList.self, at: loadedList) {
            servers.formUnion(loaded.mcpServers ?? [])
            plugins.formUnion((loaded.plugins ?? []).map(pluginName(_:)))
        }
        return ConfigInventory(mcpServers: servers, plugins: plugins)
    }

    // MARK: - Private

    /// Only the keys matter; server definitions are never read.
    private struct Keys: Decodable {}

    private struct ClaudeProject: Decodable {
        let mcpServers: [String: Keys]?
    }

    private struct ClaudeJSON: Decodable {
        let mcpServers: [String: Keys]?
        let projects: [String: ClaudeProject]?
    }

    private struct Settings: Decodable {
        let enabledPlugins: [String: Bool]?
    }

    private struct LoadedList: Decodable {
        let mcpServers: [String]?
        let plugins: [String]?
    }

    private static func decode<T: Decodable>(_ type: T.Type, at url: URL?) throws -> T? {
        guard let url, FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return nil
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    /// `name@marketplace` → `name`.
    private static func pluginName(_ id: String) -> String {
        id.split(separator: "@", maxSplits: 1).first.map(String.init) ?? id
    }
}
