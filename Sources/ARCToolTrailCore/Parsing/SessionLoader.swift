//
//  SessionLoader.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Loads a session from disk: the main transcript plus `<session>/subagents/agent-*.jsonl`.
///
/// With a cache directory, parser state is stored as `<cacheDirectory>/<file name>.json` (subagent
/// files prefixed with their session) and only
/// bytes appended since the last run are parsed. A transcript that shrank is re-parsed from zero.
public struct SessionLoader: Sendable {
    public let cacheDirectory: URL?

    public init(cacheDirectory: URL?) {
        self.cacheDirectory = cacheDirectory
    }

    public func load(transcript: URL) throws -> ParsedSession {
        let main = try parse(transcript)
        let sessionDirectory = transcript.deletingPathExtension()
        let subagents = try subagentFiles(in: sessionDirectory.appending(path: "subagents")).map { file in
            let agentId = String(file.deletingPathExtension().lastPathComponent.dropFirst(Self.agentPrefix.count))
            let meta = readMeta(file.deletingPathExtension().appendingPathExtension("meta.json"))
            return try SubagentThread(agentId: agentId,
                                      parentToolUseId: meta?.toolUseId,
                                      agentType: meta?.agentType,
                                      calls: parse(file).calls)
        }
        return ParsedSession(sessionId: main.sessionId ?? sessionDirectory.lastPathComponent,
                             calls: main.calls,
                             subagents: subagents,
                             costState: main.costState,
                             compactions: main.compactions)
    }

    // MARK: - Private

    private static let agentPrefix = "agent-"

    private struct Meta: Decodable {
        let agentType: String?
        let toolUseId: String?
    }

    /// Cached parser state, tied to the file it was read from.
    private struct CacheEntry: Codable {
        let path: String
        let parser: TranscriptParser
    }

    private func subagentFiles(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return []
        }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" && $0.lastPathComponent.hasPrefix(Self.agentPrefix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func readMeta(_ url: URL) -> Meta? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(Meta.self, from: data)
    }

    private func parse(_ file: URL) throws -> TranscriptParser {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        let path = file.standardizedFileURL.path(percentEncoded: false)
        var parser = cachedParser(for: path) ?? TranscriptParser()
        if UInt64(parser.byteOffset) > size {
            parser = TranscriptParser()
        }
        let startOffset = parser.byteOffset
        try handle.seek(toOffset: UInt64(startOffset))
        try parser.consume(handle.readToEnd() ?? Data())
        if parser.byteOffset != startOffset {
            saveCache(CacheEntry(path: path, parser: parser), for: file)
        }
        return parser
    }

    /// `<file>.json`; a subagent file is prefixed with its session (`<session>__agent-<id>.jsonl.json`),
    /// because agent file names repeat across sessions.
    private func cacheURL(for file: URL) -> URL? {
        let parent = file.deletingLastPathComponent()
        let name = parent.lastPathComponent == "subagents"
            ? "\(parent.deletingLastPathComponent().lastPathComponent)__\(file.lastPathComponent)"
            : file.lastPathComponent
        return cacheDirectory?.appending(path: "\(name).json")
    }

    private func cachedParser(for path: String) -> TranscriptParser? {
        guard let url = cacheURL(for: URL(filePath: path)),
              let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
              entry.path == path else {
            return nil
        }
        return entry.parser
    }

    /// Best effort: a cache that cannot be written only costs a full parse next time.
    private func saveCache(_ entry: CacheEntry, for file: URL) {
        guard let cacheDirectory, let url = cacheURL(for: file),
              let data = try? JSONEncoder().encode(entry) else {
            return
        }
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
