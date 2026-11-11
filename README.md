# ARCToolTrail

See which **skills, MCP servers, plugins, subagents and built-in tools** a Claude Code session
used, and roughly what each one cost, both live and at the end of the session.

Claude Code already shows the session's total cost and context. ARCToolTrail breaks that total
down by tool:

```
Skills
  plugin-authoring  ×1  $0.04
MCP
  firecrawl  ×7  $0.19
Subagents
  Explore  ×1  $0.45
Built-in
  Bash  ×13 (7 in subagents)  $0.10
  Edit  ×7  $0.08

Attributed $1.09 of session $1.97 (estimate, source: costState)

Loaded, never used:
  server revenuecat
  plugin swift-lsp
```

It has two parts:

- **`tooltrail`**: a Swift CLI that reads the session transcript (`~/.claude/projects/…/<session>.jsonl`
  and its `subagents/`) and prints a report, a statusline line, an Obsidian note or a JSON export.
- **`arc-tooltrail`**: an optional Claude Code mod. It adds a live pane and a `/tooltrail`
  command. The pane's buttons call the CLI.

The CLI and the statusline line work without the mod.

## Install

### CLI

You need a Swift 6 toolchain (macOS 14 or later, or Linux).

```sh
git clone https://github.com/arclabs-studio/ARCToolTrail.git
cd ARCToolTrail
swift build -c release
cp .build/release/tooltrail /usr/local/bin/   # or anywhere on your PATH
```

### Mod

You need a Claude Code version that supports mods (2.1.322 or later). At the prompt of a terminal
session:

```
/plugin install arc-tooltrail --marketplace arclabs-studio/ARCToolTrail
```

From a shell:

```sh
claude plugin install arc-tooltrail --marketplace arclabs-studio/ARCToolTrail
```

In the desktop app, where `/plugin` does not run: click + next to the prompt box, then Plugins,
then Add marketplace with `arclabs-studio/ARCToolTrail`, then Add plugin.

If `tooltrail` is not on the `PATH` Claude Code runs with, set the mod's `binary` option to its
full path in `/config`.

## Use

| Command | What it does |
|---|---|
| `tooltrail report --session <id>` | Text report. Add `--json` for JSON. `--transcript <path>` reads a file directly. |
| `tooltrail statusline` | Reads Claude Code's statusline JSON on stdin and prints one line. |
| `tooltrail note --session <id>` | Writes the report as a Markdown note in an Obsidian vault (`--vault`, or `$TOOLTRAIL_VAULT`), under `ToolTrail/`. |
| `tooltrail export --session <id>` | Writes the JSON report (default `~/.cache/tooltrail/exports/<id>.json`, or `--out`). |

`tooltrail <command> --help` lists every option.

### Statusline

Add the line to your existing statusline script:

```sh
input=$(cat)
# … your current statusline output …
command -v tooltrail >/dev/null && printf '%s' "$input" | tooltrail statusline
```

Parsing is incremental. Each run reads only the bytes added since the previous run, with state
cached in `~/.cache/tooltrail/`, so a refresh takes a few tens of milliseconds.

### Mod

- `/tooltrail` opens the **Session tools** pane: tools grouped by category, with use counts and
  estimated cost. It refreshes after tool calls and turns.
- **Nota Obsidian** writes the note, **Exportar JSON** writes the JSON file, and
  **Sugerir limpieza** lists configured MCP servers and plugins that the session never used.
- When the session ends, a summary line with the three most expensive tools is logged. For live
  costs under the prompt, use the [statusline](#statusline) line.

## How the cost is estimated

The numbers are **estimates**. The API bills a whole request, not individual tools, so
ARCToolTrail splits the cost with this rule:

- A tool use gets an equal share of the **output tokens** of the response that emitted it.
- It also gets an equal share of the **new input** (uncached input and cache writes) of the next
  request. That new input is mostly the tool's result.
- **Cache reads are never attributed.** They are the shared context that every turn pays for.
  This is why the attributed total is always lower than the session total.
- A **subagent** gets its whole transcript's cost. Tools used inside a subagent are counted but
  carry no cost of their own, because the subagent already holds it.

Tokens are priced with the built-in table in
[`BundledPrices.swift`](Sources/ARCToolTrailCore/Pricing/BundledPrices.swift), in USD per million
tokens (Anthropic list prices as of 2026-11-03; the table's `asOf` and `source` fields say where
they come from). Cache writes cost 1.25× input (5-minute TTL) and 2× input (1-hour TTL).
When Claude Code has written a `cost-state` record (usually at the end of a session), each model's
figures are scaled to match Claude Code's own cost for that model.

To add or correct a model, write `~/.config/tooltrail/prices.json` in the same shape. Its entries
replace the bundled ones. A model with no price shows tokens only.

## Limitations

- Fast mode, long-context surcharges and other per-request price changes are not in the price
  table. When a `cost-state` record is present, the scaling corrects for them.
- Only `Skill` tool calls count as skill uses. A skill injected by a hook or typed as a slash
  command is not seen.
- Cleanup suggestions come from `~/.claude.json` (top level plus the current project) and
  `enabledPlugins` in `~/.claude/settings.json`. claude.ai connectors are not listed there. Pass
  `--loaded <file>` (`{"mcpServers": [...], "plugins": [...]}`) to add them. A plugin that only
  ships hooks can show as unused even though it ran.
- The transcript format is Claude Code's internal format and can change between releases.

## Development

```sh
make test                      # Swift Testing suite
claude plugin validate mod
claude plugin test mod
```

## License

MIT. See [LICENSE](LICENSE).
