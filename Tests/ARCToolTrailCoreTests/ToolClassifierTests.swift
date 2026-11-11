//
//  ToolClassifierTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Testing

struct ToolClassifierTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let label: String
        let toolUse: ToolUse
        let expected: ToolIdentity
        var testDescription: String {
            label
        }
    }

    // Oracle: the rule list in the `ToolClassifier` doc comment.
    static let cases: [Case] = [Case(label: "Skill without plugin",
                                     toolUse: ToolUse(id: "t1", name: "Skill", skill: "brainstorming"),
                                     expected: ToolIdentity(category: .skill, name: "brainstorming")),
                                Case(label: "Skill with plugin prefix",
                                     toolUse: ToolUse(id: "t2", name: "Skill", skill: "superpowers:brainstorming"),
                                     expected: ToolIdentity(category: .plugin, name: "superpowers:brainstorming",
                                                            plugin: "superpowers")),
                                Case(label: "plugin MCP tool",
                                     toolUse: ToolUse(id: "t3", name: "mcp__plugin_slack_slack__slack_send_message"),
                                     expected: ToolIdentity(category: .plugin, name: "slack:slack", plugin: "slack",
                                                            server: "slack")),
                                Case(label: "plugin MCP tool, plugin and server differ",
                                     toolUse: ToolUse(id: "t4", name: "mcp__plugin_cc-tools_memory__recall"),
                                     expected: ToolIdentity(category: .plugin, name: "cc-tools:memory",
                                                            plugin: "cc-tools",
                                                            server: "memory")),
                                Case(label: "plain MCP tool",
                                     toolUse: ToolUse(id: "t5", name: "mcp__firecrawl__firecrawl_search"),
                                     expected: ToolIdentity(category: .mcp, name: "firecrawl", server: "firecrawl")),
                                Case(label: "plain MCP server with hyphen",
                                     toolUse: ToolUse(id: "t6", name: "mcp__arc-workflow__create_branch"),
                                     expected: ToolIdentity(category: .mcp, name: "arc-workflow",
                                                            server: "arc-workflow")),
                                Case(label: "claude.ai connector",
                                     toolUse: ToolUse(id: "t7", name: "mcp__claude_ai_Linear__list_issues"),
                                     expected: ToolIdentity(category: .mcp, name: "claude_ai_Linear",
                                                            server: "claude_ai_Linear",
                                                            isConnector: true)),
                                Case(label: "Agent with subagent_type",
                                     toolUse: ToolUse(id: "t8", name: "Agent", subagentType: "Explore"),
                                     expected: ToolIdentity(category: .subagent, name: "Explore")),
                                Case(label: "Agent without subagent_type",
                                     toolUse: ToolUse(id: "t9", name: "Agent"),
                                     expected: ToolIdentity(category: .subagent, name: "general-purpose")),
                                Case(label: "plugin subagent",
                                     toolUse: ToolUse(id: "t10", name: "Agent",
                                                      subagentType: "feature-dev:code-reviewer"),
                                     expected: ToolIdentity(category: .subagent, name: "feature-dev:code-reviewer",
                                                            plugin: "feature-dev")),
                                Case(label: "builtin Bash",
                                     toolUse: ToolUse(id: "t11", name: "Bash"),
                                     expected: ToolIdentity(category: .builtin, name: "Bash")),
                                Case(label: "builtin Read",
                                     toolUse: ToolUse(id: "t12", name: "Read"),
                                     expected: ToolIdentity(category: .builtin, name: "Read"))]

    @Test("Classifies each tool use per the documented rules", .tags(.unit, .critical), arguments: cases)
    func classifies(_ testCase: Case) {
        // Given a raw tool use
        // When it is classified
        let identity = ToolClassifier.identity(for: testCase.toolUse)

        // Then the identity matches the documented rule
        #expect(identity == testCase.expected)
    }
}
