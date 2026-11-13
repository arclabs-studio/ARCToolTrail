//
//  StatuslineInput.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// The fields tooltrail reads from the JSON Claude Code pipes to a statusline command.
///
/// Every field is optional. `rate_limits.*.resets_at` is accepted as epoch seconds (a number or a
/// numeric string) or as an ISO 8601 string; a window missing either field decodes as `nil`.
public struct StatuslineInput: Decodable, Hashable, Sendable {
    public let sessionId: String?
    public let transcriptPath: String?
    public let cwd: String?
    /// `context_window.context_window_size`, in tokens.
    public let contextWindowSize: Int?
    /// `rate_limits.five_hour`.
    public let fiveHour: WindowSample?
    /// `rate_limits.seven_day`.
    public let sevenDay: WindowSample?

    public init(sessionId: String?,
                transcriptPath: String?,
                cwd: String?,
                contextWindowSize: Int? = nil,
                fiveHour: WindowSample? = nil,
                sevenDay: WindowSample? = nil) {
        self.sessionId = sessionId
        self.transcriptPath = transcriptPath
        self.cwd = cwd
        self.contextWindowSize = contextWindowSize
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try? container.decodeIfPresent(String.self, forKey: .sessionId)
        transcriptPath = try? container.decodeIfPresent(String.self, forKey: .transcriptPath)
        cwd = try? container.decodeIfPresent(String.self, forKey: .cwd)
        let context = try? container.decodeIfPresent(StatuslineContextWindow.self, forKey: .contextWindow)
        contextWindowSize = context?.contextWindowSize
        let limits = try? container.decodeIfPresent(StatuslineRateLimits.self, forKey: .rateLimits)
        fiveHour = limits?.fiveHour?.sample
        sevenDay = limits?.sevenDay?.sample
    }

    // MARK: - Private

    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case contextWindow = "context_window"
        case rateLimits = "rate_limits"
    }
}
