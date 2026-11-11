//
//  ReportFiles.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Where the CLI writes a report's note and export.
public enum ReportFiles {
    /// `<UTC day> <first 8 characters of the session id>.md`, e.g. `2026-11-11 6495b37d.md`.
    public static func noteFileName(for report: SessionReport) -> String {
        let day = report.generatedAt.formatted(.iso8601.year().month().day())
        return "\(day) \(report.sessionId.prefix(8)).md"
    }

    /// The vault root for a path as typed in settings or the environment.
    ///
    /// A leading `~` or `~/` is resolved in `home`, so one shared setting such as
    /// `~/ObsidianVault` works for every user. Other paths are used as given;
    /// `~user` forms are not expanded.
    public static func vaultURL(_ path: String, home: URL) -> URL {
        if path == "~" {
            return home
        }
        if path.hasPrefix("~/") {
            return home.appending(path: String(path.dropFirst(2)))
        }
        return URL(filePath: path)
    }

    /// `<cacheDirectory>/exports/<sessionId>.json`.
    public static func defaultExportURL(cacheDirectory: URL, sessionId: String) -> URL {
        cacheDirectory.appending(path: "exports/\(sessionId).json")
    }
}
