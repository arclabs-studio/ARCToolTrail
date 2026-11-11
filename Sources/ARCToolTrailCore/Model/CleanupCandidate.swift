//
//  CleanupCandidate.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// Something configured or loaded in the session that was never used.
public struct CleanupCandidate: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case mcpServer
        case plugin
    }

    public let kind: Kind
    public let name: String

    public init(kind: Kind, name: String) {
        self.kind = kind
        self.name = name
    }
}
