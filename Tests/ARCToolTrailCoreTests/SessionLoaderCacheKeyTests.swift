//
//  SessionLoaderCacheKeyTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation
import Testing
@testable import ARCToolTrailCore

@Suite("SessionLoader cache keys")
struct SessionLoaderCacheKeyTests {
    /// Copies the fixture session to `<root>/<name>.jsonl` + `<root>/<name>/subagents/`.
    private func copyFixture(as name: String, into root: URL) throws -> URL {
        let source = try Fixtures.sessionDirectory()
        let transcript = root.appending(path: "\(name).jsonl")
        try FileManager.default.copyItem(at: source.appending(path: "session.jsonl"), to: transcript)
        try FileManager.default.copyItem(at: source.appending(path: "session", directoryHint: .isDirectory),
                                         to: root.appending(path: name, directoryHint: .isDirectory))
        return transcript
    }

    @Test("Same-named subagent files of two sessions keep separate cache entries", .tags(.integration))
    func separateEntries() throws {
        // Given two sessions whose subagent files are both agent-a1.jsonl, loaded A then B
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let cache = temp.url.appending(path: "cache", directoryHint: .isDirectory)
        let sessionA = try copyFixture(as: "session-a", into: temp.url)
        let sessionB = try copyFixture(as: "session-b", into: temp.url)
        let sut = SessionLoader(cacheDirectory: cache)
        _ = try sut.load(transcript: sessionA)
        _ = try sut.load(transcript: sessionB)

        // When A's subagent file changes in place (same length) and A is loaded again
        let agentA = temp.url.appending(path: "session-a/subagents/agent-a1.jsonl")
        let original = try String(contentsOf: agentA, encoding: .utf8)
        try original.replacingOccurrences(of: "claude-sonnet-5-5", with: "claude-sonnet-5-X")
            .write(to: agentA, atomically: false, encoding: .utf8)
        let reloaded = try sut.load(transcript: sessionA)

        // Then A's cached subagent state was still there (B did not overwrite it): old model kept
        let models = Set(reloaded.subagents.flatMap(\.calls).map(\.model))
        #expect(models == ["claude-sonnet-5-5"])
    }
}
