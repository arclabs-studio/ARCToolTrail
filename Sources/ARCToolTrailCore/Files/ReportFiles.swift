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

    /// `<cacheDirectory>/exports/<sessionId>.json`.
    public static func defaultExportURL(cacheDirectory: URL, sessionId: String) -> URL {
        cacheDirectory.appending(path: "exports/\(sessionId).json")
    }
}
