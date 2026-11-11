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
}
