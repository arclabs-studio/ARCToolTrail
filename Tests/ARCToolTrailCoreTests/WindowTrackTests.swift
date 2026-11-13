//
//  WindowTrackTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 13/11/2026.
//

import Foundation
import Testing
@testable import ARCToolTrailCore

struct WindowTrackTests {
    private let reset = Date(timeIntervalSince1970: 1_794_405_600)

    private func sample(_ used: Double, resets: Date? = nil) -> WindowSample {
        WindowSample(usedPercentage: used, resetsAt: resets ?? reset)
    }

    private func makeSUT(start: Double = 10) -> WindowTrack {
        WindowTrack(first: sample(start))
    }

    @Test("A new track starts at the first sample with no points", .tags(.unit)) func start() {
        // Given a first sample at 10 %
        let sut = makeSUT(start: 10)

        // Then nothing has been consumed yet
        #expect(sut.start == 10)
        #expect(sut.latest == 10)
        #expect(sut.closedPoints == 0)
        #expect(sut.resetsAt == reset)
        #expect(sut.points == 0)
    }

    @Test("Growth inside the window adds latest minus start", .tags(.unit, .critical)) func growth() {
        // Given a track started at 10
        var sut = makeSUT()

        // When usage grows to 14
        sut.record(sample(14))

        // Then 4 points
        #expect(sut.points == 4)
    }

    @Test("A lower sample never lowers latest", .tags(.unit, .critical)) func latestNonDecreasing() {
        // Given a track that reached 14
        var sut = makeSUT()
        sut.record(sample(14))

        // When a lower value (13) arrives in the same window
        sut.record(sample(13))

        // Then latest stays 14 and points stay 4
        #expect(sut.latest == 14)
        #expect(sut.points == 4)
    }

    @Test("Rollover closes the finished segment and restarts from zero", .tags(.unit, .critical)) func rollover() {
        // Given a track 10 -> 14 -> 13
        var sut = makeSUT()
        sut.record(sample(14))
        sut.record(sample(13))

        // When a sample for the next window arrives at 3, then 5
        let next = reset.addingTimeInterval(5 * 3600)
        sut.record(sample(3, resets: next))
        sut.record(sample(5, resets: next))

        // Then (14 - 10) + (5 - 0) = 9
        #expect(sut.closedPoints == 4)
        #expect(sut.start == 0)
        #expect(sut.latest == 5)
        #expect(sut.resetsAt == next)
        #expect(sut.points == 9)
    }

    @Test("A stale sample from an older window is ignored", .tags(.unit, .critical)) func staleSample() {
        // Given a track that already rolled over: 10 -> 14, then window 2 at 3
        var sut = makeSUT()
        sut.record(sample(14))
        let next = reset.addingTimeInterval(5 * 3600)
        sut.record(sample(3, resets: next))
        let before = sut

        // When a sample for the first window arrives late
        sut.record(sample(99, resets: reset))

        // Then nothing changes
        #expect(sut == before)
        #expect(sut.points == 4 + 3)
    }

    @Test("resets_at jitter up to 60 s is the same window; beyond it rolls over", .tags(.unit, .critical),
          arguments: [(-61.0, false), (-30.0, true), (-60.0, true), (30.0, true), (60.0, true), (61.0, false)])
    func jitter(offset: Double, sameWindow: Bool) {
        // Given a track started at 10 with reset time `reset`
        var sut = makeSUT()

        // When a sample at 12 arrives with resets_at shifted by `offset` seconds
        sut.record(sample(12, resets: reset.addingTimeInterval(offset)))

        // Then within 60 s it is the same window (points 2); later it rolls over (start 0, latest 12);
        // earlier it is stale and ignored (points 0)
        if sameWindow {
            #expect(sut.points == 2)
            #expect(sut.closedPoints == 0)
            #expect(sut.resetsAt == reset)
        } else if offset > 0 {
            #expect(sut.closedPoints == 0)
            #expect(sut.start == 0)
            #expect(sut.latest == 12)
            #expect(sut.points == 12)
        } else {
            #expect(sut.points == 0)
            #expect(sut.latest == 10)
        }
    }
}
