import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { TrailCategory, TrailItem, TrailReport, TrailView, TrailWindows } from '../types'

const PANE = 'tooltrail'
const TITLE = 'Session tools'
const REFRESH_MS = 2000
// After a failed run, wait this long before trying again (a missing binary would otherwise spawn every 2 s).
const RETRY_MS = 30000
const CATEGORIES: readonly { id: TrailCategory; title: string }[] = [
  { id: 'skill', title: 'Skills' },
  { id: 'mcp', title: 'MCP' },
  { id: 'plugin', title: 'Plugins' },
  { id: 'subagent', title: 'Subagents' },
  { id: 'builtin', title: 'Built-in' },
]

// Change the tag when TrailView changes: it declines what an earlier version stored.
const view = atom(
  { plugin: 'arc-tooltrail', key: 'view' } as const,
  { report: null, message: '', showCleanup: false } as TrailView,
  { shape: 'view-2' },
)

/** A 0–1 share as `18%`; `<1%` below half a percent, `0%` at zero (same as the CLI). */
export function formatShare(share: number): string {
  if (share <= 0) return '0%'
  if (share < 0.005) return '<1%'
  return `${Math.round(share * 100)}%`
}

/** Token counts: `780`, `8.0k`, `1.2M`. */
export function formatUnits(value: number): string {
  if (value < 1000) return `${Math.round(value)}`
  if (value < 1_000_000) return `${(value / 1000).toFixed(1)}k`
  return `${(value / 1_000_000).toFixed(1)}M`
}

/** Percentage points with one decimal: `0.0` at zero, `<0.1` above zero but below 0.05 (same as the CLI). */
export function formatPoints(points: number): string {
  return points > 0 && points < 0.05 ? '<0.1' : Math.max(0, points).toFixed(1)
}

/** `5h +2.0 pp · 7d +0.5 pp`, with `—` for a window not seen. */
export function formatWindows(windows: TrailWindows): string {
  const part = (points: number | undefined) => (points === undefined ? '—' : `+${formatPoints(points)} pp`)
  return `5h ${part(windows.fiveHour)} · 7d ${part(windows.sevenDay)}`
}

/** One pane row: `name ×uses share`, then context carry and 5-hour window points when above zero. */
export function describeItem(item: TrailItem): string {
  let row = `${item.identity.name} ×${item.uses} ${formatShare(item.sessionShare)}`
  if (item.contextCarry > 0) row += ` ctx ${formatUnits(item.contextCarry)}`
  const fiveHour = item.windowPoints?.fiveHour
  if (fiveHour !== undefined && fiveHour > 0) row += ` ~${formatPoints(fiveHour)}pp5h`
  return row
}

/** `attributed 84% of 23.8k units`, plus the session's window use when known. */
export function describeTotals(report: TrailReport): string {
  const attributed = report.sessionWeighted > 0 ? report.attributedWeighted / report.sessionWeighted : 0
  const totals = `attributed ${formatShare(attributed)} of ${formatUnits(report.sessionWeighted)} units`
  return report.windowDelta === undefined ? totals : `${totals} · ${formatWindows(report.windowDelta)} (est.)`
}

/** One-line summary for the session-end log: top three items by weighted units. */
export function summarize(report: TrailReport): string {
  if (report.items.length === 0) return 'tooltrail: no tools yet'
  const top = [...report.items]
    .sort((a, b) => b.weighted - a.weighted || b.uses - a.uses)
    .slice(0, 3)
    .map(item => `${item.identity.name}×${item.uses} ${formatShare(item.sessionShare)}`)
  return `tooltrail: ${top.join(' · ')}`
}

function itemsIn(report: TrailReport, category: TrailCategory): TrailItem[] {
  return report.items.filter(item => item.identity.category === category)
}

/** Runs `tooltrail <args> --session <this session's id>`. */
async function runCLI($: EngineInterface, binary: string, args: string[]) {
  const id = await $.session.id()
  return $.process.run([binary, ...args, '--session', id], { timeoutMs: 15000 })
}

function describe(error: unknown): string {
  return `tooltrail: ${error instanceof Error ? error.message : String(error)}`
}

export const register: Register = (on, options) => {
  const binary = typeof options.binary === 'string' && options.binary !== '' ? options.binary : 'tooltrail'
  const vaultArgs = typeof options.vault === 'string' && options.vault !== '' ? ['--vault', options.vault] : []
  let isDirty = true
  let isRunning = false
  let retryAt = 0
  let timer: { cancel: () => void } | undefined

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'tooltrail',
      description: 'Show the skills, MCP tools, plugins and subagents this session used, with their share of its tokens',
    })

    const fail = async (message: string) => {
      // Stay dirty so the next attempt runs once the back-off has passed.
      isDirty = true
      retryAt = (await $.clock.now()) + RETRY_MS
      await update($, view, state => ({ ...state, message }))
    }
    const refresh = async () => {
      if (!isDirty || isRunning || (await $.clock.now()) < retryAt) return
      isDirty = false
      isRunning = true
      try {
        const run = await runCLI($, binary, ['report', '--json'])
        if (run.exitCode !== 0) {
          await fail(run.stderr.trim() || `tooltrail exited ${run.exitCode}`)
        } else if (run.isStdoutTruncated) {
          await fail('tooltrail: report too large to read')
        } else {
          const report = JSON.parse(run.stdout) as TrailReport
          await update($, view, state => ({ ...state, report, message: '' }))
        }
      } catch (error) {
        await fail(describe(error))
      } finally {
        isRunning = false
      }
    }
    // A second session.start in the same module (e.g. a reload of the engine's copy) must not stack timers.
    timer?.cancel()
    timer = $.clock.every(REFRESH_MS, () => void refresh())

    return next(e)
  })

  // The transcript gets the tool use before it runs and the next call's usage after:
  // mark dirty on both edges so the timer picks them up.
  on('tool.call', ($, e, next) => {
    isDirty = true
    return next(e)
  })

  on('turn.complete', ($, e, next) => {
    isDirty = true
    return next(e)
  })

  on('command.run', { command: 'tooltrail' }, async $ => {
    isDirty = true
    const opened = await $.ui.open({ id: PANE, title: TITLE })
    return { text: opened.isPlaced ? 'Session tools pane opened.' : 'Session tools pane is waiting for room on screen.' }
  })

  on('session.end', async ($, e, next) => {
    const state = await read($, view)
    if (state.report !== null) $.ui.log(`${summarize(state.report)} · ${describeTotals(state.report)}`)
    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const state = await read($, view)
    const report = state.report

    const act = (args: string[], done: string) => () => {
      void (async () => {
        let message: string
        try {
          const run = await runCLI($, binary, args)
          message = run.exitCode === 0 ? `${done} ${run.stdout.trim()}` : run.stderr.trim()
        } catch (error) {
          message = describe(error)
        }
        await update($, view, current => ({ ...current, message }))
      })()
    }
    const toggleCleanup = () => {
      void update($, view, current => ({ ...current, showCleanup: !current.showCleanup }))
    }

    return (
      <Box flexDirection="column">
        {report === null && <Text dimColor>No report yet.</Text>}
        {report !== null && report.items.length === 0 && <Text dimColor>No tools used yet.</Text>}
        {report !== null &&
          CATEGORIES.filter(category => itemsIn(report, category.id).length > 0).map(category => (
            <Box flexDirection="column" key={category.id}>
              <Text bold>{category.title}</Text>
              {itemsIn(report, category.id).map(item => (
                <Text key={`${category.id}:${item.identity.name}`}>
                  {'  '}
                  {describeItem(item)}
                </Text>
              ))}
            </Box>
          ))}
        {report !== null && <Text dimColor>{describeTotals(report)}</Text>}
        {state.showCleanup && report !== null && (
          <Box flexDirection="column">
            <Text bold>Loaded, never used</Text>
            {report.cleanup.length === 0 && <Text dimColor>  Nothing to clean up.</Text>}
            {report.cleanup.map(candidate => (
              <Text key={`${candidate.kind}:${candidate.name}`}>
                {'  '}
                {candidate.kind === 'mcpServer' ? 'MCP' : 'plugin'} {candidate.name}
              </Text>
            ))}
          </Box>
        )}
        <Box flexDirection="row">
          {/* Hotkeys work once the pane holds the keyboard (ctrl+x tab, or a click in fullscreen). */}
          <Button key="note" hotkey="n" onPress={act(['note', ...vaultArgs], 'Note written:')}>
            n: Nota Obsidian
          </Button>
          <Button key="export" hotkey="e" onPress={act(['export'], 'Exported:')}>
            e: Exportar JSON
          </Button>
          <Button key="cleanup" hotkey="c" onPress={toggleCleanup}>
            c: Sugerir limpieza
          </Button>
        </Box>
        {state.message !== '' && <Text dimColor>{state.message}</Text>}
      </Box>
    )
  })
}
