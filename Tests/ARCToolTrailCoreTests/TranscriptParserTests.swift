//
//  TranscriptParserTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation
import Testing

struct TranscriptParserTests {
    private func makeSUT() -> TranscriptParser {
        TranscriptParser()
    }

    private func data(_ text: String) -> Data {
        Data(text.utf8)
    }

    private func assistantLine(id: String, usage: String, session: String = "s-1", seconds: Int = 1) -> String {
        """
        {"type":"assistant","sessionId":"\(session)","timestamp":"2026-11-11T09:00:0\(seconds).000Z",\
        "message":{"id":"\(id)","model":"claude-opus-5-5","content":[{"type":"text","text":"x"}],\
        "usage":\(usage)}}
        """
    }

    // MARK: - Dedupe and merge

    @Test("Fixture: split responses collapse to four calls in order", .tags(.unit,
                                                                            .critical)) func dedupesByMessageId() throws {
        // Given the fixture (msg_A x2 records, msg_B x2, msg_C x1, msg_D x1)
        var sut = makeSUT()
        let bytes = try Fixtures.transcriptData()

        // When consuming it whole
        sut.consume(bytes)

        // Then there are 4 calls, usage counted once each, tool uses merged in order, timestamps from the
        // first record of each call
        #expect(sut.calls.map(\.messageId) == ["msg_A", "msg_B", "msg_C", "msg_D"])
        #expect(sut.calls == SampleSession.mainCalls)
        #expect(sut.byteOffset == bytes.count)
    }

    @Test("Fixture: compact_boundary before msg_D is recorded as call index 3", .tags(.unit, .critical))
    func fixtureCompactions() throws {
        // Given the fixture (compact_boundary record sits between msg_C's tool results and msg_D)
        var sut = makeSUT()

        // When consuming it whole
        try sut.consume(Fixtures.transcriptData())

        // Then the boundary points at the index of the first call after it
        #expect(sut.compactions == [3])
    }

    @Test("Each compact_boundary appends the call count at that moment; other system records do not",
          .tags(.unit, .critical)) func compactionsTrackCallCount() {
        // Given a boundary before any call, one after the first call, a non-boundary system record, and a
        // boundary after the second call
        var sut = makeSUT()
        let boundary = #"{"type":"system","subtype":"compact_boundary","sessionId":"s-1"}"#
        let other = #"{"type":"system","subtype":"informational","sessionId":"s-1"}"#
        let text = [boundary,
                    assistantLine(id: "m1", usage: #"{"input_tokens":1,"output_tokens":1}"#),
                    boundary,
                    other,
                    assistantLine(id: "m2", usage: #"{"input_tokens":1,"output_tokens":1}"#, seconds: 2),
                    boundary].joined(separator: "\n") + "\n"

        // When consuming
        sut.consume(data(text))

        // Then the boundaries sit at 0, 1 and 2
        #expect(sut.compactions == [0, 1, 2])
    }

    @Test("Compactions survive incremental consumption split around the boundary line", .tags(.unit, .critical),
          arguments: [14, 15]) func compactionsAcrossIncrementalConsume(linesFirst: Int) throws {
        // Given the fixture; line 15 is the compact_boundary, so 14 lines stop before it and 15 end with it
        let bytes = try Fixtures.transcriptData()
        var sut = makeSUT()

        // When consuming the first lines, then the rest from the parser's byteOffset
        sut.consume(firstLines(bytes, count: linesFirst))
        sut.consume(bytes.subdata(in: sut.byteOffset ..< bytes.count))

        // Then the boundary is recorded exactly once, pointing at msg_D
        #expect(sut.compactions == [3])
        #expect(sut.calls == SampleSession.mainCalls)
    }

    @Test("Usage repeated across records is counted once", .tags(.unit, .critical)) func usageCountedOnce() throws {
        // Given msg_A, which appears in two records with identical usage (output 400)
        var sut = makeSUT()

        // When consuming the fixture
        try sut.consume(Fixtures.transcriptData())

        // Then output is 400 (not 800) and the sum over calls equals the cost-state token totals
        let msgA = try #require(sut.calls.first)
        #expect(msgA.usage.output == 400)
        let total = sut.calls.reduce(TokenUsage.zero) { $0 + $1.usage }
        // input 10+20+40+60, output 400+600+200+100, cache read 1000+3000+6000+7000,
        // write 5m 2000+0+0+400, write 1h 0+3000+1000+0
        #expect(total == TokenUsage(input: 130, output: 1300, cacheRead: 17000,
                                    cacheWrite5m: 2400, cacheWrite1h: 4000))
    }

    @Test("Tool uses of one message spread over records are merged in order",
          .tags(.unit)) func mergesToolUses() throws {
        // Given msg_B whose Agent and Skill tool_use blocks sit in separate records
        var sut = makeSUT()
        try sut.consume(Fixtures.transcriptData())

        // When reading the merged call
        let msgB = try #require(sut.calls.first { $0.messageId == "msg_B" })

        // Then both tool uses are present, Agent first
        #expect(msgB.toolUses == [ToolUse(id: "toolu_B1", name: "Agent", subagentType: "Explore"),
                                  ToolUse(id: "toolu_B2", name: "Skill", skill: "plugin-authoring")])
    }

    // MARK: - Noise, session id, cost-state

    @Test("Noise records produce no calls", .tags(.unit)) func ignoresNoise() {
        // Given only mode, api-request, tools-used and user records
        var sut = makeSUT()
        // swiftlint:disable line_length
        let lines = """
        {"type":"mode","mode":"default","sessionId":"s-1"}
        {"type":"api-request","sessionId":"s-1","params":{"model":"claude-opus-5-5"}}
        {"type":"tools-used","tools":["Bash"],"sessionId":"s-1"}
        {"type":"user","sessionId":"s-1","timestamp":"2026-11-11T09:00:00.000Z","message":{"role":"user","content":"hi"}}

        """
        // swiftlint:enable line_length

        // When consuming
        sut.consume(data(lines))

        // Then no calls and no cost-state, but every byte is consumed
        #expect(sut.calls.isEmpty)
        #expect(sut.costState == nil)
        #expect(sut.byteOffset == lines.utf8.count)
    }

    @Test("Session id comes from the first record that carries one", .tags(.unit)) func capturesSessionId() {
        // Given a record without sessionId followed by two with different ones
        var sut = makeSUT()
        let lines = """
        {"type":"mode","mode":"default"}
        {"type":"mode","mode":"default","sessionId":"s-1"}
        {"type":"mode","mode":"default","sessionId":"s-2"}

        """

        // When consuming
        sut.consume(data(lines))

        // Then it is "s-1"
        #expect(sut.sessionId == "s-1")
    }

    @Test("Fixture: session id and cost-state are captured",
          .tags(.unit, .critical)) func capturesFixtureSessionAndCostState() throws {
        // Given the fixture, whose last record is cost-state (total 0.2; opus 0.15; sonnet 0.05)
        var sut = makeSUT()

        // When consuming
        try sut.consume(Fixtures.transcriptData())

        // Then both are exposed
        #expect(sut.sessionId == "00000000-0000-4000-8000-000000000001")
        #expect(sut.costState == CostState(totalCostUSD: 0.2,
                                           costByModel: ["claude-opus-5-5": 0.15, "claude-sonnet-5-5": 0.05]))
    }

    @Test("The last cost-state record wins", .tags(.unit)) func lastCostStateWins() {
        // Given two cost-state records
        var sut = makeSUT()
        let lines = """
        {"type":"cost-state","sessionId":"s-1","totalCostUSD":0.1,"modelUsage":{"claude-opus-5-5":{"costUSD":0.1}}}
        {"type":"cost-state","sessionId":"s-1","totalCostUSD":0.3,"modelUsage":{"claude-opus-5-5":{"costUSD":0.3}}}

        """

        // When consuming
        sut.consume(data(lines))

        // Then the second one is kept
        #expect(sut.costState == CostState(totalCostUSD: 0.3, costByModel: ["claude-opus-5-5": 0.3]))
    }

    // MARK: - Usage shapes

    @Test("Usage without cache_creation split puts all cache creation in the 5m class", .tags(.unit, .critical))
    func oldUsageShape() throws {
        // Given an old-style usage with only cache_creation_input_tokens
        var sut = makeSUT()
        let usage = """
        {"input_tokens":7,"cache_creation_input_tokens":500,"cache_read_input_tokens":9,"output_tokens":3}
        """

        // When consuming
        sut.consume(data(assistantLine(id: "msg_X", usage: usage) + "\n"))

        // Then 500 lands in cacheWrite5m and 1h is zero
        let call = try #require(sut.calls.first)
        #expect(call.usage == TokenUsage(input: 7, output: 3, cacheRead: 9, cacheWrite5m: 500, cacheWrite1h: 0))
    }

    @Test("Usage with cache_creation split keeps 5m and 1h apart", .tags(.unit)) func newUsageShape() throws {
        // Given a usage with a TTL split of 300 / 700
        var sut = makeSUT()
        let usage = """
        {"input_tokens":1,"cache_creation_input_tokens":1000,"cache_read_input_tokens":2,"output_tokens":3,\
        "cache_creation":{"ephemeral_5m_input_tokens":300,"ephemeral_1h_input_tokens":700}}
        """

        // When consuming
        sut.consume(data(assistantLine(id: "msg_Y", usage: usage) + "\n"))

        // Then the split is preserved
        let call = try #require(sut.calls.first)
        #expect(call.usage == TokenUsage(input: 1, output: 3, cacheRead: 2, cacheWrite5m: 300, cacheWrite1h: 700))
    }

    // MARK: - Incremental parsing

    @Test("Two chunks split anywhere give the same state as one chunk", .tags(.unit, .critical),
          arguments: [1, 83, 84, 100, 500, 2500, 4000, 6000])
    func chunkedEqualsWhole(split: Int) throws {
        // Given the fixture and a reference parse of the whole file
        let bytes = try Fixtures.transcriptData()
        var whole = makeSUT()
        whole.consume(bytes)

        // When feeding the first `split` bytes, then everything from the parser's byteOffset on
        var sut = makeSUT()
        sut.consume(bytes.prefix(split))
        sut.consume(bytes.subdata(in: sut.byteOffset ..< bytes.count))

        // Then calls, cost-state, session id and offset are identical
        #expect(sut.calls == whole.calls)
        #expect(sut.costState == whole.costState)
        #expect(sut.sessionId == whole.sessionId)
        #expect(sut.byteOffset == bytes.count)
        #expect(sut.calls == SampleSession.mainCalls)
    }

    @Test("byteOffset counts bytes (not characters) of complete lines only",
          .tags(.unit, .critical)) func byteOffsetCompleteLinesOnly() {
        // Given two complete lines (one with a 2-byte character) and a trailing partial line
        var sut = makeSUT()
        let complete = """
        {"type":"mode","mode":"default","sessionId":"s-1"}
        {"type":"user","sessionId":"s-1","message":{"role":"user","content":"café"}}

        """
        let partial = #"{"type":"mode","mode":"def"#

        // When consuming
        sut.consume(data(complete + partial))

        // Then the offset is the UTF-8 length of the complete lines (café has 5 bytes)
        #expect(sut.byteOffset == complete.utf8.count)
        #expect(complete.utf8.count > complete.count)
    }

    @Test("A valid record without trailing newline is not consumed until the newline arrives", .tags(.unit, .critical))
    func unterminatedLineWaits() {
        // Given a full assistant record with no newline
        var sut = makeSUT()
        let line = assistantLine(id: "msg_Z", usage: #"{"input_tokens":1,"output_tokens":2}"#)

        // When consuming it
        sut.consume(data(line))

        // Then nothing is consumed
        #expect(sut.calls.isEmpty)
        #expect(sut.byteOffset == 0)

        // When the newline arrives (caller re-feeds from byteOffset)
        sut.consume(data(line + "\n"))

        // Then the call appears and the offset covers the line
        #expect(sut.calls.map(\.messageId) == ["msg_Z"])
        #expect(sut.byteOffset == line.utf8.count + 1)
    }

    @Test("State survives a Codable round trip mid-message and keeps merging",
          .tags(.unit, .critical)) func codableRoundTripThenContinue() throws {
        // Given a parser that consumed 3 fixture lines, ending after the first record of msg_A
        let bytes = try Fixtures.transcriptData()
        var original = makeSUT()
        original.consume(firstLines(bytes, count: 3))

        // When it is encoded, decoded, and fed the rest from its byteOffset
        let encoded = try JSONEncoder().encode(original)
        var restored = try JSONDecoder().decode(TranscriptParser.self, from: encoded)
        #expect(restored == original)
        restored.consume(bytes.subdata(in: restored.byteOffset ..< bytes.count))

        // Then the result equals an uninterrupted parse (the second msg_A record merges, no duplicate)
        var whole = makeSUT()
        whole.consume(bytes)
        #expect(restored == whole)
        #expect(restored.calls == SampleSession.mainCalls)
    }
}
