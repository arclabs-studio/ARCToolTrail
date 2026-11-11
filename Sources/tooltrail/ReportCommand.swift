//
//  ReportCommand.swift
//  tooltrail
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import ArgumentParser
import Foundation

/// `tooltrail report`: the full report as text or JSON.
struct ReportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "report",
                                                    abstract: "Print the per-tool report of a session.")

    @OptionGroup var options: SessionOptions

    @Flag(help: "Print JSON instead of text.") var json = false

    mutating func run() async throws {
        let report = try options.buildReport()
        if json {
            try FileHandle.standardOutput.write(contentsOf: ReportJSON.encode(report))
            print()
        } else {
            print(TextRenderer.render(report))
        }
    }
}
