//
//  Record.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// The fields tooltrail reads from one transcript line. Everything else is ignored.
struct Record: Decodable {
    let type: String?
    let subtype: String?
    let sessionId: String?
    let timestamp: String?
    let message: RecordMessage?
    let totalCostUSD: Double?
    let modelUsage: [String: RecordModelUsage]?
}
