//
//  StatuslineCommand.swift
//  tooltrail
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import ArgumentParser
import Foundation

/// `tooltrail statusline`: reads the statusline JSON on stdin and prints one line.
struct StatuslineCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "statusline",
                                                    abstract: "Print one statusline line from the statusline JSON "
                                                        + "on stdin.")

    @OptionGroup var options: SessionOptions

    @Option(help: "Number of tools shown.") var limit = 4

    mutating func run() async throws {
        let data = try FileHandle.standardInput.readToEnd() ?? Data()
        let input = try JSONDecoder().decode(StatuslineInput.self, from: data)
        var options = options
        options.transcript = options.transcript ?? input.transcriptPath
        options.session = options.session ?? input.sessionId
        options.project = options.project ?? input.cwd
        // Only the statusline sees rate_limits; a baseline that cannot be saved only loses the window figures.
        try? WindowBaseline.record(input, in: URL(filePath: options.cacheDir))
        try print(StatuslineRenderer.render(options.buildReport(), limit: limit))
    }
}
