//
//  StatuslineInputTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation
import Testing
@testable import ARCToolTrailCore

@Suite("StatuslineInput")
struct StatuslineInputTests {
    private func decode(_ json: String) throws -> StatuslineInput {
        try JSONDecoder().decode(StatuslineInput.self, from: Data(json.utf8))
    }

    private func rateLimits(fiveHour resets: String) -> String {
        #"{"rate_limits":{"five_hour":{"used_percentage":12.5,"resets_at":\#(resets)}}}"#
    }

    @Test("Reads session_id, transcript_path and cwd and ignores the rest", .tags(.unit)) func decodes() throws {
        // Given the JSON Claude Code pipes to a statusline command
        let json = """
        {"session_id":"s-1","transcript_path":"/p/s-1.jsonl","cwd":"/work",
         "model":{"id":"claude-opus-5-5"},"cost":{"total_cost_usd":1.2}}
        """

        // When decoding
        let input = try JSONDecoder().decode(StatuslineInput.self, from: Data(json.utf8))

        // Then
        #expect(input == StatuslineInput(sessionId: "s-1", transcriptPath: "/p/s-1.jsonl", cwd: "/work"))
    }

    @Test("Missing fields decode as nil", .tags(.unit)) func missingFields() throws {
        let input = try JSONDecoder().decode(StatuslineInput.self, from: Data("{}".utf8))
        #expect(input == StatuslineInput(sessionId: nil, transcriptPath: nil, cwd: nil))
    }

    // MARK: - Context window and rate limits

    @Test("Fixture statusline JSON decodes ids, context size and both windows", .tags(.unit, .critical))
    func decodesFixture() throws {
        // Given the synthetic statusline input (epoch number for 5h, ISO string for 7d)
        let data = try Fixtures.statuslineInputData()

        // When decoding
        let input = try JSONDecoder().decode(StatuslineInput.self, from: data)

        // Then 2026-11-11T14:00:00Z = 1_794_405_600 and 2026-11-15T09:00:00Z = 1_794_733_200
        #expect(input.sessionId == SampleSession.sessionId)
        #expect(input.transcriptPath == "/work/session.jsonl")
        #expect(input.cwd == "/work")
        #expect(input.contextWindowSize == 1000)
        #expect(input.fiveHour == WindowSample(usedPercentage: 12.5,
                                               resetsAt: Date(timeIntervalSince1970: 1_794_405_600)))
        #expect(input.sevenDay == WindowSample(usedPercentage: 40,
                                               resetsAt: Date(timeIntervalSince1970: 1_794_733_200)))
    }

    @Test("resets_at accepts epoch number, numeric string and ISO 8601 with or without fractions",
          .tags(.unit, .critical),
          arguments: [("1794405600", 1_794_405_600.0), (#""1794405600""#, 1_794_405_600.0),
                      (#""2026-11-11T14:00:00Z""#, 1_794_405_600.0),
                      (#""2026-11-11T14:00:00.500Z""#, 1_794_405_600.5)])
    func resetsAtFormats(raw: String, expectedEpoch: Double) throws {
        // Given a five_hour window whose resets_at is written in one of the supported shapes
        // When decoding
        let input = try decode(rateLimits(fiveHour: raw))

        // Then the date is the same instant
        let sample = try #require(input.fiveHour)
        #expect(sample.usedPercentage == 12.5)
        #expect(isClose(sample.resetsAt.timeIntervalSince1970, to: expectedEpoch, tolerance: 0.001))
        #expect(input.sevenDay == nil)
    }

    @Test("A window missing a field or with an unparseable resets_at decodes as nil, never throws",
          .tags(.unit, .critical),
          arguments: [#"{"rate_limits":{"five_hour":{"used_percentage":12.5}}}"#,
                      #"{"rate_limits":{"five_hour":{"resets_at":1794405600}}}"#,
                      #"{"rate_limits":{"five_hour":{"used_percentage":12.5,"resets_at":"soon"}}}"#,
                      #"{"rate_limits":{"five_hour":{}}}"#, #"{"rate_limits":{}}"#, #"{"rate_limits":null}"#])
    func incompleteWindowIsNil(json: String) throws {
        // Given rate_limits whose five_hour window is incomplete
        // When decoding
        let input = try decode(json)

        // Then the window is nil
        #expect(input.fiveHour == nil)
    }

    @Test("One broken window does not hide the other", .tags(.unit)) func windowsAreIndependent() throws {
        // Given a broken five_hour and a valid seven_day
        let json = """
        {"rate_limits":{"five_hour":{"used_percentage":1},
                        "seven_day":{"used_percentage":40,"resets_at":1794733200}}}
        """

        // When decoding
        let input = try decode(json)

        // Then only seven_day is present
        #expect(input.fiveHour == nil)
        #expect(input.sevenDay == WindowSample(usedPercentage: 40,
                                               resetsAt: Date(timeIntervalSince1970: 1_794_733_200)))
    }

    @Test("context_window_size is optional", .tags(.unit)) func contextWindowSize() throws {
        // Given inputs with and without context_window_size
        let with = try decode(#"{"context_window":{"context_window_size":200000}}"#)
        let without = try decode(#"{"context_window":{}}"#)

        // Then it is read when present, nil otherwise
        #expect(with.contextWindowSize == 200_000)
        #expect(without.contextWindowSize == nil)
    }
}
