//
//  SessionOptions.swift
//  tooltrail
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import ArgumentParser
import Foundation

/// Options shared by every command that reads a session.
struct SessionOptions: ParsableArguments {
    @Option(help: "Path to the session transcript (.jsonl).") var transcript: String?

    @Option(help: "Session id; the transcript is looked up under --projects-dir.") var session: String?

    @Option(help: "Claude Code projects directory.")
    var projectsDir: String = URL.homeDirectory.appending(path: ".claude/projects").path(percentEncoded: false)

    @Option(help: "Price override file (same shape as the bundled prices.json).")
    var prices: String = URL.homeDirectory.appending(path: ".config/tooltrail/prices.json").path(percentEncoded: false)

    @Option(help: "Directory for the incremental parse cache.")
    var cacheDir: String = URL.homeDirectory.appending(path: ".cache/tooltrail").path(percentEncoded: false)

    @Flag(help: "Parse the whole transcript without the cache.") var noCache = false

    @Option(help: "~/.claude.json, for the configured MCP servers.")
    var claudeJson: String = URL.homeDirectory.appending(path: ".claude.json").path(percentEncoded: false)

    @Option(help: "Claude Code settings.json, for the enabled plugins.")
    var settings: String = URL.homeDirectory.appending(path: ".claude/settings.json").path(percentEncoded: false)

    @Option(help: "Project directory whose MCP servers count as configured (default: current directory).")
    var project: String?

    @Option(help: "JSON file {\"mcpServers\": [..], \"plugins\": [..]} with what the session loaded.")
    var loaded: String?

    /// The transcript to read: `--transcript`, or `<projects-dir>/*/<session>.jsonl`.
    func transcriptURL() throws -> URL {
        if let transcript {
            return URL(filePath: transcript)
        }
        guard let session else {
            throw ToolTrailCLIError.missingSession
        }
        return try SessionLocator(projectsDirectory: URL(filePath: projectsDir)).transcript(forSession: session)
    }

    /// Loads the session and builds its report.
    func buildReport() throws -> SessionReport {
        try ReportRequest(transcript: transcriptURL(),
                          cacheDirectory: noCache ? nil : URL(filePath: cacheDir),
                          pricesOverride: URL(filePath: prices),
                          claudeJSON: URL(filePath: claudeJson),
                          settingsJSON: URL(filePath: settings),
                          projectPath: project ?? FileManager.default.currentDirectoryPath,
                          loadedList: loaded.map { URL(filePath: $0) }).run()
    }
}
