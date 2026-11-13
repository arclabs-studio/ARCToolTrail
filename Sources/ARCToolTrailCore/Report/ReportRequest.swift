//
//  ReportRequest.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Everything needed to build one report: the transcript and the config files around it.
public struct ReportRequest: Sendable {
    public let transcript: URL
    /// Incremental parse cache; `nil` parses the whole transcript.
    public let cacheDirectory: URL?
    public let pricesOverride: URL?
    public let claudeJSON: URL?
    public let settingsJSON: URL?
    public let projectPath: String?
    public let loadedList: URL?
    /// Directory holding `<sessionId>.windows.json` (see ``WindowBaseline``); `nil` reads none.
    public let windowsDirectory: URL?

    public init(transcript: URL,
                cacheDirectory: URL?,
                pricesOverride: URL?,
                claudeJSON: URL?,
                settingsJSON: URL?,
                projectPath: String?,
                loadedList: URL?,
                windowsDirectory: URL? = nil) {
        self.transcript = transcript
        self.cacheDirectory = cacheDirectory
        self.pricesOverride = pricesOverride
        self.claudeJSON = claudeJSON
        self.settingsJSON = settingsJSON
        self.projectPath = projectPath
        self.loadedList = loadedList
        self.windowsDirectory = windowsDirectory
    }

    /// Loads the session, prices, inventory and window baseline, and builds the report.
    public func run(now: Date = .now) throws -> SessionReport {
        let session = try SessionLoader(cacheDirectory: cacheDirectory).load(transcript: transcript)
        let prices = try PriceTable.load(override: pricesOverride)
        let inventory = try ConfigInventory.load(claudeJSON: claudeJSON,
                                                 settingsJSON: settingsJSON,
                                                 projectPath: projectPath,
                                                 loadedList: loadedList)
        let windows = windowsDirectory.flatMap { directory in
            WindowBaseline.isSafe(session.sessionId)
                ? WindowBaseline.load(from: WindowBaseline.url(in: directory, sessionId: session.sessionId))
                : nil
        }
        return ReportBuilder(prices: prices).build(session, inventory: inventory, windows: windows, now: now)
    }
}
