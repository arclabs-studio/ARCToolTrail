//
//  ToolTrail.swift
//  tooltrail
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ArgumentParser

@main
struct ToolTrail: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "tooltrail",
                                                    abstract: "Per-tool usage and estimated cost of a Claude Code "
                                                        + "session.",
                                                    version: "0.1.1",
                                                    subcommands: [ReportCommand.self,
                                                                  StatuslineCommand.self,
                                                                  NoteCommand.self,
                                                                  ExportCommand.self])
}
