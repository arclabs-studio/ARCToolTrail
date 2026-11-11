# CLAUDE.md — AI Agent Context

Context for Claude Code and other AI agents working in this repository. The studio-wide
rules in `~/.claude/CLAUDE.md` (ARC engineering constitution) apply; this file adds what is
specific to ARCToolTrail.

---

## Project Overview

ARCToolTrail shows which skills, MCP servers, plugins, subagents and built-in tools a Claude
Code session used, and roughly what each one cost, live and at the end of the session.

It has two parts:

- **`tooltrail`**: a Swift CLI over the `ARCToolTrailCore` library. It reads a session
  transcript and prints a text or JSON report, a statusline line, an Obsidian note or a JSON
  export.
- **`arc-tooltrail`**: a Claude Code mod in `mod/` (TypeScript/TSX). It adds a live pane and the
  `/tooltrail` command. Every action shells out to the CLI.

The CLI works without the mod. The mod holds no parsing or cost logic.

---

## Tech Stack

| Component | Technology |
|---|---|
| Language | Swift 6.0 tools, strict concurrency, macOS 14+ |
| Package manager | Swift Package Manager |
| CLI parsing | `apple/swift-argument-parser` 1.8.2 (the only dependency) |
| Tests | Swift Testing (`@Suite`, `@Test`, tags `.unit` / `.integration` / `.critical`) |
| Mod | Claude Code mod API (`claude-code` module), TSX, tested with `claude plugin test` |
| Lint / format | SwiftLint + SwiftFormat, configs from ARCDevTools |

---

## Repository Layout

```
ARCToolTrail/
├── Package.swift
├── Makefile                          lint / format / fix / build / build-release / test / clean
├── README.md                         user docs: install, use, cost method, limitations
├── CHANGELOG.md
├── CLAUDE.md                         (this file)
├── .claude-plugin/marketplace.json   marketplace "arclabs-tooltrail" → ./mod
├── Sources/
│   ├── ARCToolTrailCore/
│   │   ├── Model/                    value types (ToolUse, APICall, TokenUsage, SessionReport…)
│   │   ├── Parsing/                  TranscriptParser, Record* DTOs, SessionLoader (cache)
│   │   ├── Classification/           ToolClassifier
│   │   ├── Attribution/              CostAttributor
│   │   ├── Pricing/                  PriceTable, ModelPrice, BundledPrices (built-in table)
│   │   ├── Report/                   ReportBuilder, Tally, Pricing, ReportRequest
│   │   ├── Cleanup/                  ConfigInventory (~/.claude.json, settings.json)
│   │   ├── Session/                  SessionLocator (+ error)
│   │   ├── Files/                    ReportFiles (note name, default export path)
│   │   └── Rendering/                Text, Statusline, MarkdownNote, ReportJSON
│   └── tooltrail/                    @main CLI: report, statusline, note, export
├── Tests/ARCToolTrailCoreTests/
│   ├── Support/                      fixture loading, SampleSession builders
│   └── Fixtures/synthetic-session/   synthetic transcript + subagent transcript
└── mod/
    ├── .claude-plugin/plugin.json    userConfig: binary, vault
    ├── hooks/hooks.json
    ├── hooks/register.tsx            the whole mod
    ├── types/index.d.ts              TrailReport / TrailView contract
    └── tests/register.test.tsx
```

The CLI target stays thin: argument parsing and I/O wiring only. Logic goes in
`ARCToolTrailCore`, where it is tested (`ReportRequest.run(now:)` is the CLI's entry point
into Core).

---

## Common Commands

```bash
make lint                  # SwiftLint
make format                # SwiftFormat dry run
make fix                   # SwiftFormat apply
make build-release         # .build/release/tooltrail
claude plugin validate mod
claude plugin test mod
```

Build and run the Swift tests through the **Xcode MCP** (open the package directory in Xcode,
then `BuildProject` / `RunAllTests` / `GetBuildLog`). Do not run `swift build`, `swift test`
or `make build` / `make test` unless the user asks for the CLI by name; the constitution's
tooling rule applies here too.

Definition of done for a change: zero build warnings, all Swift tests green, lint and format
clean, and for mod changes `claude plugin validate mod` + `claude plugin test mod` passing.

---

## Domain Notes

These are the facts the code relies on. Read them before changing parsing or cost logic.

### Transcript shape

- Transcripts live at `~/.claude/projects/<project>/<session>.jsonl`; subagent transcripts at
  `<session>/subagents/agent-<id>.jsonl` with an `agent-<id>.meta.json` holding `toolUseId`
  and `agentType`.
- One API response is split across several records that share `message.id` and repeat the
  same `usage`. Deduplicate by `message.id`, or usage is counted several times.
- `cost-state` records are rare (usually at session end). They carry `totalCostUSD` and
  `modelUsage[model].costUSD`, and their totals include subagents.
- The format is Claude Code's internal format and can change between releases. Keep the
  `Record*` DTOs tolerant: optional fields, unknown records skipped.

### Classification

- `Skill` → skill, or plugin when the skill name is `plugin:name`.
- `mcp__plugin_<p>_<s>__<tool>` → plugin `p:s`.
- `mcp__<server>__<tool>` → MCP server (`claude_ai_` prefix marks a claude.ai connector).
- `Agent` → subagent (`general-purpose` when no type is given).
- Anything else → built-in.

### Cost attribution

- A tool use gets `output / n` of the response that emitted it, plus
  `(input + cacheWrite5m + cacheWrite1h) / n` of the next request (`n` = tool uses sharing it).
- Cache reads are never attributed, so the attributed total is always below the session total.
- A subagent's whole transcript cost goes to its `Agent` tool use; tools inside it are counted
  but carry no cost.
- Prices come from `Pricing/BundledPrices.swift`, a JSON table in a raw string (USD per million
  tokens, with `asOf` and `source`), overridable by `~/.config/tooltrail/prices.json`. It is
  compiled in, not a resource, so the binary is one self-contained file: do not move it back into
  a resource bundle. Cache writes cost 1.25× input (5 min TTL)
  and 2× input (1 h TTL). Model names are normalised (`anthropic.` prefix, `[1m]` suffix,
  `-YYYYMMDD` date).
- When a `cost-state` record exists, each model's estimate is scaled to Claude Code's own cost
  for that model.
- When you change a price, update `asOf` and `source` in the same commit, and never add a model
  whose prices you have not verified.

### Incremental parsing

- `TranscriptParser` is `Codable` state; `consume(_:)` takes only complete lines and keeps a
  byte offset. `SessionLoader` caches the parser state as JSON in `~/.cache/tooltrail/`.
- Subagent cache keys are prefixed with the session (`<session>__agent-<id>.jsonl.json`), so
  two sessions' `agent-a1` never collide.
- A file shorter than its cached offset is re-parsed from the start.
- The statusline runs on every refresh: keep it on the cached path (tens of milliseconds).

---

## Mod Notes

- `register.tsx` refreshes every 2 s when dirty (`tool.call` and `turn.complete` mark it
  dirty) and backs off 30 s after a failed CLI run, so a missing binary does not spawn every
  2 s.
- `runCLI` must stay a top-level function taking `$`; `claude plugin validate` rejects `$`
  passed to a nested helper. `tool.call` hooks must stay non-gating.
- The mod sets no status entry: the statusline line (`tooltrail statusline`) already shows
  the costs, and both together repeat the same text.
- The pane's view atom has a `shape` tag (`view-1`). Change the tag whenever `TrailView`
  changes.
- In mod tests a throwing hook is skipped; simulate a failing `process.run` with `{ deny }`.
- The mod reads the CLI's JSON (`types/index.d.ts` mirrors `ReportJSON`). A change to the JSON
  shape needs both sides updated in the same PR.
- Button labels are in Spanish (`Nota Obsidian`, `Exportar JSON`, `Sugerir limpieza`); the
  rest of the UI is English.

---

## Tests and Fixtures

- Fixtures are **synthetic**. This is a public repository: never copy real transcript data
  into it, anonymised or not. Build new fixtures that reproduce real record shapes.
- `synthetic-session` holds four API calls (`msg_A`–`msg_D`), a `cost-state` (total 0.2:
  opus 0.15, sonnet 0.05) and one subagent (`agent-a1`, `toolUseId` `toolu_B1`, `Explore`).
  Tests assert on these numbers; changing the fixture means changing the oracles on purpose.
- Do not add a `.swift-version` file: SwiftFormat then rewrites test function names into raw
  identifiers.

---

## Releases

Git flow: `feature/*` → PR into `develop`; release PR `develop` → `main`; annotated tag
`vX.Y.Z` on `main`; GitHub release from the CHANGELOG section; then merge `main` back into
`develop`. Bump the version in `Sources/tooltrail/ToolTrail.swift` and
`mod/.claude-plugin/plugin.json` together. The marketplace install reads `main`, so users only
get a change after a release.
