//
//  SessionLocatorError.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Why `SessionLocator` could not return a transcript.
public enum SessionLocatorError: LocalizedError, Equatable, Sendable {
    /// The id is empty or contains `/` or `..`, so it could point outside the projects directory.
    case invalidSessionId(String)
    /// No `<project>/<id>.jsonl` exists under the projects directory.
    case notFound(sessionId: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidSessionId(id):
            "invalid session id \"\(id)\""
        case let .notFound(sessionId):
            "no transcript for session \(sessionId)"
        }
    }
}
