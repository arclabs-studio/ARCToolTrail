//
//  ExportCommand.swift
//  tooltrail
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import ArgumentParser
import Foundation

/// `tooltrail export`: writes the JSON report to a file and prints its path.
struct ExportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "export",
                                                    abstract: "Write the JSON report to a file.")

    @OptionGroup var options: SessionOptions

    @Option(help: "Output file (default: <cache-dir>/exports/<session>.json).") var out: String?

    mutating func run() async throws {
        let report = try options.buildReport()
        let file = out.map { URL(filePath: $0) }
            ?? ReportFiles.defaultExportURL(cacheDirectory: URL(filePath: options.cacheDir),
                                            sessionId: report.sessionId)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try ReportJSON.encode(report).write(to: file, options: .atomic)
        print(file.path(percentEncoded: false))
    }
}
