//
//  ReportJSON.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Stable JSON form of a `SessionReport` (ISO 8601 dates, sorted keys).
public enum ReportJSON {
    public static func encode(_ report: SessionReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    public static func decode(_ data: Data) throws -> SessionReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionReport.self, from: data)
    }
}
