//
//  TranscriptParser.swift
//  ARCToolTrailCore
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import Foundation

/// Incremental parser for a Claude Code session transcript (JSONL).
///
/// Feed it the bytes from `byteOffset` to end of file. Only complete lines (ending in `\n`) are
/// consumed; a trailing partial line is left for the next call. The parser is `Codable` so its state
/// can be cached between statusline refreshes.
///
/// Assistant responses are split across several records that share `message.id` and repeat the same
/// `usage`; the parser merges them into one `APICall` and counts the usage once.
public struct TranscriptParser: Hashable, Codable, Sendable {
    /// Bytes of complete lines consumed so far.
    public private(set) var byteOffset: Int = 0
    /// Calls in order of first appearance.
    public private(set) var calls: [APICall] = []
    /// Last `cost-state` record seen.
    public private(set) var costState: CostState?
    /// `sessionId` of the first record that carries one.
    public private(set) var sessionId: String?

    /// Index into `calls` by `message.id`.
    private var callIndex: [String: Int] = [:]

    public init() {}

    /// Parses every complete line in `data`, which must start at `byteOffset` of the file.
    public mutating func consume(_ data: Data) {
        guard let lastNewline = data.lastIndex(of: Self.newline) else {
            return
        }
        let complete = data[data.startIndex ..< lastNewline]
        for line in complete.split(separator: Self.newline, omittingEmptySubsequences: true) {
            consumeLine(Data(line))
        }
        byteOffset += data.distance(from: data.startIndex, to: lastNewline) + 1
    }

    // MARK: - Private

    private static let newline = UInt8(ascii: "\n")
    private static let assistantMarker = Data(#""type":"assistant""#.utf8)
    private static let costStateMarker = Data(#""type":"cost-state""#.utf8)
    private static let fractionalDate = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plainDate = Date.ISO8601FormatStyle()

    private mutating func consumeLine(_ line: Data) {
        let isAssistant = line.range(of: Self.assistantMarker) != nil
        let isCostState = line.range(of: Self.costStateMarker) != nil
        guard isAssistant || isCostState || sessionId == nil, let record = try? JSONDecoder().decode(Record.self,
                                                                                                     from: line) else {
            return
        }
        if sessionId == nil {
            sessionId = record.sessionId
        }
        switch record.type {
        case "assistant":
            if let message = record.message {
                merge(message, timestamp: record.timestamp.flatMap(Self.date(from:)))
            }
        case "cost-state":
            if let total = record.totalCostUSD {
                let byModel = (record.modelUsage ?? [:]).compactMapValues(\.costUSD)
                costState = CostState(totalCostUSD: total, costByModel: byModel)
            }
        default:
            break
        }
    }

    private mutating func merge(_ message: RecordMessage, timestamp: Date?) {
        let toolUses = message.content.compactMap(\.toolUse)
        if let index = callIndex[message.id] {
            calls[index].toolUses.append(contentsOf: toolUses)
            return
        }
        callIndex[message.id] = calls.count
        calls.append(APICall(messageId: message.id,
                             model: message.model ?? "",
                             usage: message.usage?.tokenUsage ?? .zero,
                             toolUses: toolUses,
                             timestamp: timestamp))
    }

    private static func date(from text: String) -> Date? {
        (try? Date(text, strategy: fractionalDate)) ?? (try? Date(text, strategy: plainDate))
    }
}
