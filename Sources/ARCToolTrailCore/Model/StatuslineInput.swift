//
//  StatuslineInput.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

/// The fields tooltrail reads from the JSON Claude Code pipes to a statusline command.
public struct StatuslineInput: Decodable, Hashable, Sendable {
    public let sessionId: String?
    public let transcriptPath: String?
    public let cwd: String?

    public init(sessionId: String?, transcriptPath: String?, cwd: String?) {
        self.sessionId = sessionId
        self.transcriptPath = transcriptPath
        self.cwd = cwd
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
    }
}
