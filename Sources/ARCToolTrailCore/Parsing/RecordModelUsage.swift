//
//  RecordModelUsage.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// One model's entry in a `cost-state` record's `modelUsage`.
struct RecordModelUsage: Decodable {
    let costUSD: Double?
}
