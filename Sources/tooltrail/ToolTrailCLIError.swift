//
//  ToolTrailCLIError.swift
//  tooltrail
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Errors the CLI reports to the user.
enum ToolTrailCLIError: LocalizedError {
    case missingSession
    case missingVault

    var errorDescription: String? {
        switch self {
        case .missingSession:
            "pass --transcript <path> or --session <id>"
        case .missingVault:
            "no Obsidian vault: pass --vault <path> or set TOOLTRAIL_VAULT"
        }
    }
}
