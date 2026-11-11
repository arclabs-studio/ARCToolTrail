//
//  ConfigInventoryTests.swift
//  ARCToolTrailCoreTests
//
//  Created by ARC Labs Studio on 11/11/2026.
//

import ARCToolTrailCore
import Foundation
import Testing

struct ConfigInventoryTests {
    private static let claudeJSON = """
    {"numStartups": 3,
     "mcpServers": {"global-one": {"command": "x"}},
     "projects": {
       "/work/alpha": {"mcpServers": {"alpha-server": {"command": "y"}}, "allowedTools": []},
       "/work/beta": {"mcpServers": {"beta-server": {"command": "z"}}}
     }}
    """

    private static let settingsJSON = """
    {"enabledPlugins": {"slack@official-marketplace": true,
                        "caveman@studio-marketplace": false,
                        "revenuecat@studio-marketplace": true}}
    """

    private func makeSUT(temp: TempDirectory,
                         claude: String? = ConfigInventoryTests.claudeJSON,
                         settings: String? = ConfigInventoryTests.settingsJSON,
                         loaded: String? = nil,
                         projectPath: String? = "/work/alpha") throws -> ConfigInventory {
        let claudeURL = try claude.map { try temp.write($0, as: "claude.json") }
        let settingsURL = try settings.map { try temp.write($0, as: "settings.json") }
        let loadedURL = try loaded.map { try temp.write($0, as: "loaded.json") }
        return try ConfigInventory.load(claudeJSON: claudeURL, settingsJSON: settingsURL,
                                        projectPath: projectPath, loadedList: loadedURL)
    }

    @Test("Reads top-level and current-project MCP servers only", .tags(.integration,
                                                                        .critical)) func mcpServers() throws {
        // Given a ~/.claude.json with global and per-project servers
        let temp = try TempDirectory.make()
        defer { temp.remove() }

        // When loading for project /work/alpha
        let sut = try makeSUT(temp: temp)

        // Then global + alpha, not beta
        #expect(sut.mcpServers == ["global-one", "alpha-server"])
    }

    @Test("Without a project path only top-level servers are read", .tags(.integration)) func noProjectPath() throws {
        // Given the same file
        let temp = try TempDirectory.make()
        defer { temp.remove() }

        // When loading with projectPath nil
        let sut = try makeSUT(temp: temp, projectPath: nil)

        // Then project servers are left out
        #expect(sut.mcpServers == ["global-one"])
    }

    @Test("Enabled plugins lose their marketplace suffix; disabled ones are skipped", .tags(.integration, .critical))
    func plugins() throws {
        // Given a settings file with two enabled and one disabled plugin
        let temp = try TempDirectory.make()
        defer { temp.remove() }

        // When loading
        let sut = try makeSUT(temp: temp)

        // Then names are bare and caveman (false) is absent
        #expect(sut.plugins == ["slack", "revenuecat"])
    }

    @Test("Loaded list is merged into the result", .tags(.integration)) func loadedListMerged() throws {
        // Given a loaded list naming a connector, a duplicate server and an extra plugin
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let loaded = #"{"mcpServers": ["claude_ai_Linear", "global-one"], "plugins": ["extra-plugin", "slack"]}"#

        // When loading
        let sut = try makeSUT(temp: temp, loaded: loaded)

        // Then the sets are unions
        #expect(sut.mcpServers == ["global-one", "alpha-server", "claude_ai_Linear"])
        #expect(sut.plugins == ["slack", "revenuecat", "extra-plugin"])
    }

    @Test("Missing and nil files are skipped", .tags(.integration, .critical)) func missingFilesSkipped() throws {
        // Given a claude.json that exists, a settings path that does not, and no loaded list
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let claudeURL = try temp.write(Self.claudeJSON, as: "claude.json")
        let missing = temp.url.appending(path: "absent.json")

        // When loading
        let sut = try ConfigInventory.load(claudeJSON: claudeURL, settingsJSON: missing,
                                           projectPath: "/work/alpha", loadedList: nil)

        // Then servers are read and plugins are empty, without an error
        #expect(sut.mcpServers == ["global-one", "alpha-server"])
        #expect(sut.plugins.isEmpty)
    }

    @Test("All sources missing yields an empty inventory", .tags(.integration)) func allMissing() throws {
        // Given three paths that do not exist
        let temp = try TempDirectory.make()
        defer { temp.remove() }
        let missing = temp.url.appending(path: "absent.json")

        // When loading
        let sut = try ConfigInventory.load(claudeJSON: missing, settingsJSON: missing,
                                           projectPath: "/work/alpha", loadedList: missing)

        // Then it is empty
        #expect(sut.mcpServers.isEmpty)
        #expect(sut.plugins.isEmpty)
    }
}
