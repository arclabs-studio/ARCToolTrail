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
                                                    abstract: "Per-tool share of a Claude Code session's tokens "
                                                        + "and rate-limit windows.",
                                                    version: "0.1.2",
                                                    subcommands: [ReportCommand.self,
                                                                  StatuslineCommand.self,
                                                                  NoteCommand.self,
                                                                  ExportCommand.self])
}
