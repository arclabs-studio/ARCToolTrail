# ARCToolTrail

See which **skills, MCP servers, plugins, subagents and built-in tools** a Claude Code session
used, and how much of the session's tokens and of your 5-hour and 7-day usage windows each one
took, both live and at the end of the session.

Claude Code already shows the session's totals and your window usage. ARCToolTrail breaks them
down by tool:

```
MCP
  Tool       Uses  %sess  units/use  ctx carry  %ctx  ~5h pp  ~7d pp    USD
  firecrawl    ×7    21%       9.1k      48.0k    4%     0.8     0.1  $0.19

Subagents
  Tool     Uses  %sess  units/use  ctx carry  %ctx  ~5h pp  ~7d pp    USD
  Explore    ×1    35%     105.0k      12.3k    1%     1.4     0.2  $0.45

Built-in
  Tool          Uses  %sess  units/use  ctx carry  %ctx  ~5h pp  ~7d pp    USD
  Bash  ×13 (7 sub)     9%       4.5k      21.6k    2%     0.4    <0.1  $0.10

Session 300.4k units (price-weighted tokens), 65% attributed to tools
Window use this session: 5h +4.0 pp · 7d +0.6 pp (estimate: includes parallel sessions; weighting is a price proxy)
Attributed $1.09 of session $1.97 (estimate, source: costState)

Loaded, never used:
  server revenuecat
  plugin swift-lsp
```

The columns are explained in [How usage is measured](#how-usage-is-measured). USD stays in the
report, the note and the JSON as secondary data; the statusline and the pane show no dollars.

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
| `tooltrail note --session <id>` | Writes the report as a Markdown note in an Obsidian vault (`--vault`, or `$TOOLTRAIL_VAULT`; a leading `~/` is your home), under `ToolTrail/`. |
| `tooltrail export --session <id>` | Writes the JSON report (default `~/.cache/tooltrail/exports/<id>.json`, or `--out`). |

`tooltrail <command> --help` lists every option.

### Statusline

Add the line to your existing statusline script:

```sh
input=$(cat)
# … your current statusline output …
command -v tooltrail >/dev/null && printf '%s' "$input" | tooltrail statusline
```

It prints the top tools by weight with their share of the session, and, once the window baseline
has grown, their estimated 5-hour window points:

```
Read×12 18% ~0.4pp5h · github×3 9% ~0.2pp5h · Explore×1 7% ~0.2pp5h · Bash×20 6% ~0.1pp5h · +5
```

Parsing is incremental. Each run reads only the bytes added since the previous run, with state
cached in `~/.cache/tooltrail/`, so a refresh takes a few tens of milliseconds.

The statusline is the only command that receives `rate_limits`, so each run also records the
session's window baseline in `~/.cache/tooltrail/<session>.windows.json`. `report`, `note`,
`export` and the mod read that file; without it they show no window figures.

### Mod

- `/tooltrail` opens the **Session tools** pane: tools grouped by category, each with its use
  count, share of the session, context carry (`ctx`) and estimated 5-hour window points (`~pp5h`).
  It refreshes after tool calls and turns.
- **Nota Obsidian** writes the note, **Exportar JSON** writes the JSON file, and
  **Sugerir limpieza** lists configured MCP servers and plugins that the session never used.
- To use the buttons from the keyboard, press `ctrl+x` `Tab` to give the pane the keyboard, then
  `n`, `e` or `c` (or `Tab` to a button and Enter). `Esc` returns to the prompt. Clicks work in
  fullscreen mode.
- When the session ends, a summary line with the three heaviest tools is logged. For live
  figures under the prompt, use the [statusline](#statusline) line.

## How usage is measured

The numbers are **estimates**. The API bills a whole request, not individual tools, so
ARCToolTrail splits each request's tokens with this rule:

- A tool use gets an equal share of the **output tokens** of the response that emitted it.
- It also gets an equal share of the **new input** (uncached input and cache writes) of the next
  request. That new input is mostly the tool's result.
- **Cache reads are never attributed.** They are the shared context that every turn pays for.
  This is why the attributed total is always lower than the session total.
- A **subagent** gets its whole transcript's tokens except cache reads, like the main thread.
  Its cache reads count as its context carry instead. Tools used inside a subagent are counted
  but carry no tokens of their own, because the subagent already holds them.

### Weighted units

Token types do not weigh the same, so tokens are turned into **weighted units**: 1 unit is one
input token of the same model, and every other type is weighted by its list price relative to
input (output 5×, cache reads 0.05×–0.1×, cache writes 1.25× or 2×). A model without a price uses
the standard ratios (5, 0.1, 1.25, 2). Anthropic does not publish how plan limits weight token
types, so this is a **price proxy**, not the limits' own accounting.

| Column | Meaning |
|---|---|
| `%sess` | The tool's weighted units over the whole session's (every call, subagents included). The shares add up to the attributed percentage, never above 100%. |
| `units/use` | Weighted units per use made outside subagents (per use when every use was inside one). |
| `ctx carry` | Tokens the tool's results added, times the later requests that re-read them before the next compaction (`compact_boundary`): roughly how many tokens it made the model re-read. A subagent also carries its own cache reads. |
| `%ctx` | Tokens the tool added since the last compaction, over the context window size the statusline reports. Empty without a window baseline. |
| `~5h pp` / `~7d pp` | Estimated percentage points of each window: the session's window use × `%sess`. Empty without a window baseline. |

### Window points

The statusline JSON gives each window only as `used_percentage` and `resets_at`; there are no
absolute token counts. The baseline file keeps the first percentage seen in the session and the
highest since. When `resets_at` moves forward the window rolled over: the finished segment is
banked and a new one starts at 0. The session's delta is the sum.

Every session on the account moves the same windows, so with sessions running in parallel the
delta, and each tool's share of it, is an **upper bound** for this session.

### USD

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
  table. When a `cost-state` record is present, the scaling corrects USD for them; weighted
  units ignore them.
- Window points are estimates: the weighting is a price proxy, and parallel sessions inflate the
  session's delta. Window figures need the statusline line installed, since only it sees
  `rate_limits`.
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
