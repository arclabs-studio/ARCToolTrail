//
//  SessionLocatorTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation
import Testing
@testable import ARCToolTrailCore

@Suite("SessionLocator")
struct SessionLocatorTests {
    private func makeSUT(_ root: URL) -> SessionLocator {
        SessionLocator(projectsDirectory: root)
    }

    @Test("Finds <projects>/<any project>/<id>.jsonl", .tags(.integration)) func findsTranscript() throws {
        // Given two project folders, the session in the second
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let projectA = temp.url.appending(path: "-Users-a-one", directoryHint: .isDirectory)
        let projectB = temp.url.appending(path: "-Users-a-two", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: projectA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectB, withIntermediateDirectories: true)
        let expected = projectB.appending(path: "abc-123.jsonl")
        try Data("{}\n".utf8).write(to: expected)

        // When locating the session
        let found = try makeSUT(temp.url).transcript(forSession: "abc-123")

        // Then the file in the second project is returned
        #expect(found.standardizedFileURL == expected.standardizedFileURL)
    }

    @Test("Unknown session throws notFound", .tags(.integration)) func notFound() throws {
        // Given an empty projects directory
        let temp = try TempDirectory.make()
        defer { temp.remove() }

        // When / Then
        #expect(throws: SessionLocatorError.notFound(sessionId: "nope")) {
            try makeSUT(temp.url).transcript(forSession: "nope")
        }
    }

    @Test("Ids that could leave the projects directory are rejected",
          .tags(.unit, .critical),
          arguments: ["", "../x", "a/b", "..", "x/../y"]) func rejectsPathIds(id: String) throws {
        // Given any projects directory
        let sut = makeSUT(URL(filePath: "/nonexistent-projects"))

        // When / Then
        #expect(throws: SessionLocatorError.invalidSessionId(id)) {
            try sut.transcript(forSession: id)
        }
    }
}
