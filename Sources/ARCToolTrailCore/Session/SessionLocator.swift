//
//  SessionLocator.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Finds a session's transcript under Claude Code's projects directory (`~/.claude/projects`).
public struct SessionLocator: Sendable {
    public let projectsDirectory: URL

    public init(projectsDirectory: URL) {
        self.projectsDirectory = projectsDirectory
    }

    /// `<projectsDirectory>/<any project>/<sessionId>.jsonl`.
    public func transcript(forSession sessionId: String) throws -> URL {
        guard !sessionId.isEmpty, !sessionId.contains("/"), !sessionId.contains("..") else {
            throw SessionLocatorError.invalidSessionId(sessionId)
        }
        let projects = (try? FileManager.default.contentsOfDirectory(at: projectsDirectory,
                                                                     includingPropertiesForKeys: nil)) ?? []
        for project in projects {
            let candidate = project.appending(path: "\(sessionId).jsonl")
            if FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
                return candidate
            }
        }
        throw SessionLocatorError.notFound(sessionId: sessionId)
    }
}
