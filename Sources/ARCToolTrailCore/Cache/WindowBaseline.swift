//
//  WindowBaseline.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 13/11/2026.
//

import Foundation

/// Per-session record of the rate-limit windows, kept in `<cache>/<sessionId>.windows.json`.
///
/// Only the statusline receives `rate_limits`, so `tooltrail statusline` records every tick here and
/// the other commands read the file.
public struct WindowBaseline: Hashable, Codable, Sendable {
    public private(set) var fiveHour: WindowTrack?
    public private(set) var sevenDay: WindowTrack?
    /// Last `context_window.context_window_size` seen.
    public private(set) var contextWindowSize: Int?

    public init() {}

    /// Starts or advances each window present in `input`; absent windows are left untouched.
    public mutating func record(_ input: StatuslineInput) {
        if let sample = input.fiveHour {
            fiveHour = Self.advance(fiveHour, with: sample)
        }
        if let sample = input.sevenDay {
            sevenDay = Self.advance(sevenDay, with: sample)
        }
        if let size = input.contextWindowSize {
            contextWindowSize = size
        }
    }

    /// Points used in each window this session; `nil` when no window was ever seen.
    public var delta: WindowDelta? {
        guard fiveHour != nil || sevenDay != nil else {
            return nil
        }
        return WindowDelta(fiveHour: fiveHour?.points, sevenDay: sevenDay?.points)
    }

    /// Loads the baseline of `input`'s session from `directory`, records `input` and saves it.
    /// Does nothing when `input` has no session id, or one that is not a plain file name.
    public static func record(_ input: StatuslineInput, in directory: URL) throws {
        guard let sessionId = input.sessionId, isSafe(sessionId) else {
            return
        }
        let file = url(in: directory, sessionId: sessionId)
        var baseline = load(from: file) ?? WindowBaseline()
        baseline.record(input)
        try baseline.save(to: file)
    }

    /// `<directory>/<sessionId>.windows.json`.
    public static func url(in directory: URL, sessionId: String) -> URL {
        directory.appending(path: "\(sessionId).windows.json")
    }

    /// The saved baseline, or `nil` when the file is missing or unreadable.
    public static func load(from url: URL) -> WindowBaseline? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(WindowBaseline.self, from: data)
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    /// `true` when `sessionId` can name a file in the cache directory: not empty, no `/`, no `..`
    /// (the same rule as ``SessionLocator``), so stdin JSON cannot write outside it.
    static func isSafe(_ sessionId: String) -> Bool {
        !sessionId.isEmpty && !sessionId.contains("/") && !sessionId.contains("..")
    }

    // MARK: - Private

    private static func advance(_ track: WindowTrack?, with sample: WindowSample) -> WindowTrack {
        guard var track else {
            return WindowTrack(first: sample)
        }
        track.record(sample)
        return track
    }
}
