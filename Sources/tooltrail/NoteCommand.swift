//
//  NoteCommand.swift
//  tooltrail
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import ArgumentParser
import Foundation

/// `tooltrail note`: writes the report as a note in an Obsidian vault and prints its path.
struct NoteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "note",
                                                    abstract: "Write the report as an Obsidian note.")

    @OptionGroup var options: SessionOptions

    @Option(help: "Vault root; a leading ~/ is your home (default: $TOOLTRAIL_VAULT).") var vault: String?

    @Option(help: "Folder inside the vault.") var folder = "ToolTrail"

    mutating func run() async throws {
        guard let root = vault ?? ProcessInfo.processInfo.environment["TOOLTRAIL_VAULT"], !root.isEmpty else {
            throw ToolTrailCLIError.missingVault
        }
        let report = try options.buildReport()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let directory = ReportFiles.vaultURL(root, home: home).appending(path: folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: ReportFiles.noteFileName(for: report))
        try MarkdownNoteRenderer.render(report).write(to: file, atomically: true, encoding: .utf8)
        print(file.path(percentEncoded: false))
    }
}
