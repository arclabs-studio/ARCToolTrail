//
//  WindowBaselineTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 13/11/2026.
//

import Foundation
import Testing
@testable import ARCToolTrailCore

struct WindowBaselineTests {
    private let reset5h = Date(timeIntervalSince1970: 1_794_405_600)
    private let reset7d = Date(timeIntervalSince1970: 1_794_733_200)

    private func input(five: Double? = nil, seven: Double? = nil, size: Int? = nil,
                       fiveResets: Date? = nil) -> StatuslineInput {
        StatuslineInput(sessionId: "s-1", transcriptPath: nil, cwd: nil,
                        contextWindowSize: size,
                        fiveHour: five.map { WindowSample(usedPercentage: $0, resetsAt: fiveResets ?? reset5h) },
                        sevenDay: seven.map { WindowSample(usedPercentage: $0, resetsAt: reset7d) })
    }

    private func makeSUT() -> WindowBaseline {
        WindowBaseline()
    }

    @Test("A new baseline has no delta", .tags(.unit)) func empty() {
        // Given a baseline that saw nothing
        let sut = makeSUT()

        // Then there is no delta, windows or size
        #expect(sut.delta == nil)
        #expect(sut.fiveHour == nil)
        #expect(sut.sevenDay == nil)
        #expect(sut.contextWindowSize == nil)
    }

    @Test("The first input starts each window at its used percentage: delta is 0 pp", .tags(.unit, .critical))
    func firstInput() {
        // Given a baseline
        var sut = makeSUT()

        // When recording 5h 10 and 7d 40
        sut.record(input(five: 10, seven: 40))

        // Then both windows exist and nothing has been consumed since
        #expect(sut.fiveHour?.start == 10)
        #expect(sut.sevenDay?.start == 40)
        #expect(sut.delta == WindowDelta(fiveHour: 0, sevenDay: 0))
    }

    @Test("Growth is reported per window", .tags(.unit, .critical)) func growth() {
        // Given a baseline that saw 10 / 40
        var sut = makeSUT()
        sut.record(input(five: 10, seven: 40))

        // When usage grows to 12 / 40.5
        sut.record(input(five: 12, seven: 40.5))

        // Then 2.0 and 0.5 points
        #expect(sut.delta == WindowDelta(fiveHour: 2, sevenDay: 0.5))
    }

    @Test("Latest never decreases", .tags(.unit)) func nonDecreasing() {
        // Given a baseline that reached 14 (from 10)
        var sut = makeSUT()
        sut.record(input(five: 10))
        sut.record(input(five: 14))

        // When a lower value arrives
        sut.record(input(five: 13))

        // Then the delta is still 4
        #expect(sut.delta == WindowDelta(fiveHour: 4, sevenDay: nil))
    }

    @Test("Rollover of the 5h window accumulates (14 - 10) + 5 = 9", .tags(.unit, .critical)) func rollover() {
        // Given 10 -> 14 in the first window
        var sut = makeSUT()
        sut.record(input(five: 10))
        sut.record(input(five: 14))

        // When the next window starts at 3 and reaches 5
        let next = reset5h.addingTimeInterval(5 * 3600)
        sut.record(input(five: 3, fiveResets: next))
        sut.record(input(five: 5, fiveResets: next))

        // Then 9 points
        #expect(sut.delta?.fiveHour == 9)
    }

    @Test("A stale sample is ignored", .tags(.unit)) func stale() {
        // Given a baseline rolled over to a new window
        var sut = makeSUT()
        sut.record(input(five: 10))
        let next = reset5h.addingTimeInterval(5 * 3600)
        sut.record(input(five: 2, fiveResets: next))
        let before = sut

        // When an older window's sample shows up
        sut.record(input(five: 80))

        // Then nothing changes
        #expect(sut == before)
    }

    @Test("resets_at jitter of 30 s stays in the same window", .tags(.unit)) func jitter() {
        // Given 10 in the first window
        var sut = makeSUT()
        sut.record(input(five: 10))

        // When 12 arrives with resets_at 30 s later
        sut.record(input(five: 12, fiveResets: reset5h.addingTimeInterval(30)))

        // Then it is the same window: 2 points, not a rollover
        #expect(sut.delta?.fiveHour == 2)
        #expect(sut.fiveHour?.closedPoints == 0)
    }

    @Test("An input without rate_limits leaves windows untouched and delta nil when none was seen",
          .tags(.unit, .critical)) func missingRateLimits() {
        // Given a fresh baseline
        var sut = makeSUT()

        // When an input without windows arrives
        sut.record(input(size: 1000))

        // Then delta stays nil
        #expect(sut.delta == nil)

        // And once a window exists, an input without windows leaves it as it was
        sut.record(input(five: 10, seven: 40))
        sut.record(input(five: 12))
        sut.record(input())
        #expect(sut.delta == WindowDelta(fiveHour: 2, sevenDay: 0))
    }

    @Test("Only one window seen: the other delta is nil", .tags(.unit)) func oneWindow() {
        // Given only a 7d window
        var sut = makeSUT()
        sut.record(input(seven: 40))
        sut.record(input(seven: 41))

        // Then 5h is nil and 7d is 1
        #expect(sut.delta == WindowDelta(fiveHour: nil, sevenDay: 1))
    }

    @Test("contextWindowSize keeps the last non-nil value", .tags(.unit, .critical)) func contextWindowSize() {
        // Given a size of 1000
        var sut = makeSUT()
        sut.record(input(size: 1000))

        // When an input without a size arrives, the size is kept
        sut.record(input())
        #expect(sut.contextWindowSize == 1000)

        // And a new non-nil value replaces it
        sut.record(input(size: 200_000))
        #expect(sut.contextWindowSize == 200_000)
    }

    @Test("url is <directory>/<sessionId>.windows.json", .tags(.unit)) func url() {
        // Given a directory and a session id
        let directory = URL(filePath: "/tmp/tooltrail-windows", directoryHint: .isDirectory)

        // When building the file URL
        let url = WindowBaseline.url(in: directory, sessionId: "abc-123")

        // Then it follows the documented name
        #expect(url.lastPathComponent == "abc-123.windows.json")
        #expect(url.deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path)
    }

    @Test("Save then load returns an equal baseline, creating the directory", .tags(.integration, .critical))
    func roundTrip() throws {
        // Given a baseline with both windows and a size, and a directory that does not exist yet
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        var sut = makeSUT()
        sut.record(input(five: 10, seven: 40, size: 1000))
        sut.record(input(five: 14, seven: 41))
        let file = WindowBaseline.url(in: temp.url.appending(path: "nested/windows", directoryHint: .isDirectory),
                                      sessionId: "s-1")

        // When saving and loading
        try sut.save(to: file)
        let loaded = WindowBaseline.load(from: file)

        // Then nothing is lost
        #expect(loaded == sut)
        #expect(loaded?.delta == WindowDelta(fiveHour: 4, sevenDay: 1))
        #expect(loaded?.contextWindowSize == 1000)
    }

    @Test("record(_:in:) loads, advances and saves the per-session file", .tags(.integration, .critical))
    func recordInDirectory() throws {
        // Given an empty directory
        let temp = try TempDirectory.make()
        defer { temp.remove() }

        // When two inputs of the same session are recorded through the directory API
        try WindowBaseline.record(input(five: 10, size: 1000), in: temp.url)
        try WindowBaseline.record(input(five: 13), in: temp.url)

        // Then the file holds the accumulated baseline
        let loaded = WindowBaseline.load(from: WindowBaseline.url(in: temp.url, sessionId: "s-1"))
        #expect(loaded?.delta == WindowDelta(fiveHour: 3, sevenDay: nil))
        #expect(loaded?.contextWindowSize == 1000)
    }

    @Test("record(_:in:) without a session id writes nothing", .tags(.integration)) func recordWithoutSession() throws {
        // Given an empty directory and an input with no session id
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let anonymous = StatuslineInput(sessionId: nil, transcriptPath: nil, cwd: nil, contextWindowSize: 1000)

        // When recording
        try WindowBaseline.record(anonymous, in: temp.url)

        // Then the directory is still empty
        #expect(try FileManager.default.contentsOfDirectory(atPath: temp.url.path).isEmpty)
    }

    @Test("record(_:in:) with an unsafe session id writes nothing, inside or outside the directory",
          .tags(.integration, .critical),
          arguments: ["", "../escape", "a/b", ".."])
    func recordUnsafeSessionId(sessionId: String) throws {
        // Given a parent directory holding an empty cache directory, and an id that is empty or a path
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let cache = temp.url.appending(path: "cache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let input = StatuslineInput(sessionId: sessionId, transcriptPath: nil, cwd: nil, contextWindowSize: 1000)

        // When recording into the cache directory
        try WindowBaseline.record(input, in: cache)

        // Then neither the cache nor its parent gained a file
        #expect(try FileManager.default.contentsOfDirectory(atPath: cache.path).isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: temp.url.path) == ["cache"])
    }

    @Test("Load of a missing or unreadable file is nil", .tags(.integration)) func loadFailures() throws {
        // Given an empty directory and a file with garbage
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let garbage = try temp.write("not json", as: "bad.windows.json")

        // Then both loads are nil
        #expect(WindowBaseline.load(from: temp.url.appending(path: "missing.windows.json")) == nil)
        #expect(WindowBaseline.load(from: garbage) == nil)
    }
}
