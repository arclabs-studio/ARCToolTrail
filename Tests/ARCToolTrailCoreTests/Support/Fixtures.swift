//
//  Fixtures.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

enum FixtureError: Error {
    case missing(String)
    case unreadable(String)
}

/// Access to the bundled `Fixtures/synthetic-session` files.
enum Fixtures {
    static func sessionDirectory() throws -> URL {
        guard let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else {
            throw FixtureError.missing("Fixtures")
        }
        return root.appending(path: "synthetic-session", directoryHint: .isDirectory)
    }

    static func transcript() throws -> URL {
        try sessionDirectory().appending(path: "session.jsonl")
    }

    static func transcriptData() throws -> Data {
        try Data(contentsOf: transcript())
    }
}

extension Fixtures {
    /// `Fixtures/statusline-input.json`: a synthetic statusline payload for the fixture session.
    static func statuslineInputData() throws -> Data {
        guard let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else {
            throw FixtureError.missing("Fixtures")
        }
        return try Data(contentsOf: root.appending(path: "statusline-input.json"))
    }
}

/// A scratch directory under the system temporary directory. Call `remove()` in a `defer`.
struct TempDirectory {
    let url: URL

    static func make() throws -> TempDirectory {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "tooltrail-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return TempDirectory(url: url)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    /// Writes `text` as UTF-8 to `name` inside the directory and returns its URL.
    @discardableResult func write(_ text: String, as name: String) throws -> URL {
        let file = url.appending(path: name)
        try Data(text.utf8).write(to: file)
        return file
    }
}

/// `true` when `value` is within `tolerance` of `expected`.
func isClose(_ value: Double?, to expected: Double, tolerance: Double = 1e-9) -> Bool {
    guard let value else { return false }
    return abs(value - expected) <= tolerance
}

/// The first `count` complete lines of `data` (newline included).
func firstLines(_ data: Data, count: Int) -> Data {
    var seen = 0
    var end = 0
    for (index, byte) in data.enumerated() where byte == 0x0A {
        seen += 1
        if seen == count {
            end = index + 1
            break
        }
    }
    return Data(data.prefix(end))
}
