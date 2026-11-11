//
//  SessionLoaderTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation
import Testing

struct SessionLoaderTests {
    private func makeSUT(cacheDirectory: URL? = nil) -> SessionLoader {
        SessionLoader(cacheDirectory: cacheDirectory)
    }

    /// Copies the whole fixture session (transcript + subagents) into `temp`; returns the transcript copy.
    private func copyFixture(into temp: TempDirectory) throws -> URL {
        let destination = temp.url.appending(path: "synthetic-session", directoryHint: .isDirectory)
        try FileManager.default.copyItem(at: Fixtures.sessionDirectory(), to: destination)
        return destination.appending(path: "session.jsonl")
    }

    private func appendedLine(id: String) -> String {
        """
        {"type":"assistant","sessionId":"00000000-0000-4000-8000-000000000001","isSidechain":false,\
        "timestamp":"2026-11-11T09:01:00.000Z","message":{"id":"\(id)","model":"claude-opus-5-5",\
        "content":[{"type":"text","text":"x"}],"usage":{"input_tokens":1,"output_tokens":2}}}

        """
    }

    private func append(_ text: String, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
    }

    // MARK: - Fixture, no cache

    @Test("Loads main calls, session id and cost-state from the fixture",
          .tags(.integration, .critical)) func loadsMainThread() throws {
        // Given the fixture and a loader without cache
        let sut = makeSUT()

        // When loading
        let session = try sut.load(transcript: Fixtures.transcript())

        // Then main thread, session id and cost-state match the fixture
        #expect(session.sessionId == "00000000-0000-4000-8000-000000000001")
        #expect(session.calls == SampleSession.mainCalls)
        #expect(session.costState == SampleSession.costState)
    }

    @Test("Links the subagent thread to its launching tool use", .tags(.integration,
                                                                       .critical)) func loadsSubagent() throws {
        // Given the fixture with agent-a1.jsonl + agent-a1.meta.json
        let sut = makeSUT()

        // When loading
        let session = try sut.load(transcript: Fixtures.transcript())

        // Then one thread, linked by meta.json, with its two sonnet calls
        let thread = try #require(session.subagents.first)
        #expect(session.subagents.count == 1)
        #expect(thread.agentId == "a1")
        #expect(thread.parentToolUseId == "toolu_B1")
        #expect(thread.agentType == "Explore")
        #expect(thread.calls == [SampleSession.msgS1, SampleSession.msgS2])
    }

    @Test("Missing transcript throws", .tags(.integration)) func missingTranscriptThrows() {
        // Given a transcript path that does not exist
        let missing = FileManager.default.temporaryDirectory.appending(path: "nope-\(UUID().uuidString).jsonl")
        let sut = makeSUT()

        // When loading / Then it throws
        #expect(throws: (any Error).self) { try sut.load(transcript: missing) }
    }

    // MARK: - Cache

    @Test("Second load with a cache writes state and parses only appended bytes", .tags(.integration, .critical))
    func cacheReuseAndAppend() throws {
        // Given a temp copy of the fixture, a cache directory and a first load
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let transcript = try copyFixture(into: temp)
        let cache = temp.url.appending(path: "cache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let sut = makeSUT(cacheDirectory: cache)
        let first = try sut.load(transcript: transcript)
        #expect(first.calls == SampleSession.mainCalls)

        // Then parser state was cached
        let cached = try FileManager.default.contentsOfDirectory(atPath: cache.path)
        #expect(!cached.isEmpty)

        // When the first record is altered in place WITHOUT changing its length, and one line is appended
        // (the cached prefix must not be re-parsed; only the new bytes are)
        var bytes = try Data(contentsOf: transcript)
        let original = Data("claude-opus-5-5".utf8)
        let altered = Data("claude-opus-5-X".utf8)
        let range = try #require(bytes.range(of: original))
        bytes.replaceSubrange(range, with: altered)
        try bytes.write(to: transcript)
        try append(appendedLine(id: "msg_E"), to: transcript)
        let second = try sut.load(transcript: transcript)

        // Then the new call is picked up and the cached calls are unchanged (old model id kept)
        #expect(second.calls.map(\.messageId) == ["msg_A", "msg_B", "msg_C", "msg_D", "msg_E"])
        #expect(Array(second.calls.prefix(4)) == SampleSession.mainCalls)
        #expect(second.calls.last?.usage == TokenUsage(input: 1, output: 2))
    }

    @Test("A shrunk transcript is re-parsed from zero", .tags(.integration,
                                                              .critical)) func shrunkTranscriptReparses() throws {
        // Given a cached load of the full copy
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let transcript = try copyFixture(into: temp)
        let cache = temp.url.appending(path: "cache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let sut = makeSUT(cacheDirectory: cache)
        let full = try sut.load(transcript: transcript)
        #expect(full.calls.count == 4)

        // When the transcript is cut after line 4 (only msg_A, two records) and loaded again
        let bytes = try Data(contentsOf: transcript)
        try firstLines(bytes, count: 4).write(to: transcript)
        let shrunk = try sut.load(transcript: transcript)

        // Then only msg_A remains and the old cost-state is gone
        #expect(shrunk.calls == [SampleSession.msgA])
        #expect(shrunk.costState == nil)
    }

    @Test("Cached and uncached loads agree", .tags(.integration)) func cachedEqualsUncached() throws {
        // Given the fixture copy loaded twice with a cache
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let transcript = try copyFixture(into: temp)
        let cache = temp.url.appending(path: "cache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let cached = makeSUT(cacheDirectory: cache)
        _ = try cached.load(transcript: transcript)

        // When loading again from the warm cache and without any cache
        let warm = try cached.load(transcript: transcript)
        let plain = try makeSUT().load(transcript: transcript)

        // Then results are identical
        #expect(warm == plain)
        #expect(warm == SampleSession.make())
    }
}
