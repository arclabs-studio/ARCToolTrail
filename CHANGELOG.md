# Changelog

## [Unreleased]

### Added

- Pane buttons have hotkeys: `n` Nota Obsidian, `e` Exportar JSON, `c` Sugerir limpieza. They
  work once the pane holds the keyboard (`ctrl+x` `Tab`).

## [0.1.2] - 2026-11-11

### Changed

- `tooltrail note` resolves a leading `~/` in `--vault`, `$TOOLTRAIL_VAULT` and the mod's `vault`
  option to your home directory, so one shared setting (`~/ObsidianVault`) works on every Mac.

### Removed

- The mod's status entry. It repeated what the `tooltrail statusline` line already shows, with
  a doubled `arc-tooltrail: tooltrail:` prefix. The pane, `/tooltrail` and the session-end
  summary are unchanged.

## [0.1.1] - 2026-11-11

### Fixed

- `tooltrail` no longer crashes with `unable to find bundle named ARCToolTrail_ARCToolTrailCore`
  when the binary is copied on its own, as the README's install step does. The price table is
  now compiled into the binary instead of shipping as a resource bundle.

## [0.1.0] - 2026-11-11

### Added

- `ARCToolTrailCore`: incremental parser for Claude Code session transcripts and their subagent
  transcripts, with a parse cache in `~/.cache/tooltrail`.
- Classification of tool uses into skills, MCP servers (claude.ai connectors included), plugins,
  subagents and built-in tools.
- Per-tool cost estimate: output tokens of the emitting response plus new input of the next
  request, cache reads never attributed, whole subagent cost on its `Agent` call. Scaled to
  Claude Code's `cost-state` when present.
- Bundled `prices.json` (USD per million tokens, as of 2026-11-03), overridable with
  `~/.config/tooltrail/prices.json`.
- Cleanup suggestions: configured MCP servers and enabled plugins the session never used.
- `tooltrail` CLI with `report` (text or `--json`), `statusline`, `note` (Obsidian) and `export`
  (JSON).
- `arc-tooltrail` Claude Code mod: live **Session tools** pane, status entry, `/tooltrail`
  command, and buttons for the Obsidian note, JSON export and cleanup suggestions.
- Plugin marketplace manifest (`.claude-plugin/marketplace.json`).

[0.1.2]: https://github.com/arclabs-studio/ARCToolTrail/releases/tag/v0.1.2
[0.1.1]: https://github.com/arclabs-studio/ARCToolTrail/releases/tag/v0.1.1
[0.1.0]: https://github.com/arclabs-studio/ARCToolTrail/releases/tag/v0.1.0
