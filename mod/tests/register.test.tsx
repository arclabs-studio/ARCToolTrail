import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import { describeTotals, formatPoints, formatShare, formatUnits, formatWindows, summarize } from '../hooks/register'
import type { TrailItem, TrailReport } from '../types'

const PANE = {
  plugin: 'arc-tooltrail',
  component: 'Pane',
  requestId: 'tooltrail',
  props: {
    title: 'Session tools',
    isFocused: false,
    bodyColumns: 60,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 30 },
    view: {},
  },
} as const

const NO_TOKENS = { input: 0, output: 0, cacheRead: 0, cacheWrite5m: 0, cacheWrite1h: 0 }

/** An item whose window points are its share of the session's 5h +2.0 / 7d +0.5 pp. */
function item(identity: TrailItem['identity'], uses: number, weighted: number, contextCarry: number): TrailItem {
  const sessionShare = weighted / 20000
  return {
    identity,
    uses,
    usesInSubagents: 0,
    attributedTokens: NO_TOKENS,
    estimatedCostUSD: 0.3,
    weighted,
    sessionShare,
    weightedPerUse: weighted / uses,
    contextCarry,
    liveContextTokens: 0,
    windowPoints: { fiveHour: 2 * sessionShare, sevenDay: 0.5 * sessionShare },
  }
}

// Session 20000 units; firecrawl 20%, Explore 50%, Bash 0.3%; attributed 15000 of 20000 = 75%.
const REPORT: TrailReport = {
  sessionId: 'sid-1',
  generatedAt: '2026-11-11T09:00:00Z',
  items: [
    item({ category: 'mcp', name: 'firecrawl', server: 'firecrawl', isConnector: false }, 6, 4000, 6040),
    item({ category: 'subagent', name: 'Explore', isConnector: false }, 1, 10000, 0),
    item({ category: 'builtin', name: 'Bash', isConnector: false }, 4, 60, 0),
  ],
  sessionCostUSD: 1.97,
  attributedCostUSD: 1.104,
  costSource: 'costState',
  cleanup: [{ kind: 'mcpServer', name: 'revenuecat' }],
  sessionTokens: NO_TOKENS,
  sessionWeighted: 20000,
  attributedWeighted: 15000,
  windowDelta: { fiveHour: 2, sevenDay: 0.5 },
}

/** Stands for the engine: session id, command registry, pane placement and the CLI. */
function engine(on: On, cli: (argv: readonly string[]) => { exitCode: number; stdout: string; stderr: string }) {
  const calls: string[][] = []
  on('session.id', () => ({ value: 'sid-1' }))
  on('command.register', () => ({ value: { command: 'tooltrail' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('process.run', (_, e) => {
    calls.push([...e.argv])
    return { value: { ...cli(e.argv), isStdoutTruncated: false, isStderrTruncated: false } }
  })
  return calls
}

test('the pane groups the report by category after the first refresh', async ($, on) => {
  const clock = mock.clock(on)
  const calls = engine(on, () => ({ exitCode: 0, stdout: JSON.stringify(REPORT), stderr: '' }))

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(2000)

  expect(calls[0]).toEqual(['tooltrail', 'report', '--json', '--session', 'sid-1'])
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /^MCP$/ }))?.text).toBe('MCP')
    expect((await ui.find({ type: 'Text', text: /firecrawl/ }))?.text).toBe('  firecrawl ×6 20% ctx 6.0k ~0.4pp5h')
    expect((await ui.find({ type: 'Text', text: /Explore/ }))?.text).toBe('  Explore ×1 50% ~1.0pp5h')
    expect((await ui.find({ type: 'Text', text: /Bash/ }))?.text).toBe('  Bash ×4 <1% ~<0.1pp5h')
    expect((await ui.find({ type: 'Text', text: /attributed/ }))?.text).toBe(
      'attributed 75% of 20.0k units · 5h +2.0 pp · 7d +0.5 pp (est.)',
    )
    expect(await ui.find({ type: 'Text', text: /\$/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /^Skills$/ })).toBeUndefined()
    await ui.unmount()
  }
})

test('a refresh leaves the status line alone (the statusline script shows the costs)', async ($, on) => {
  const clock = mock.clock(on)
  const statuses: unknown[] = []
  on('ui.status', (_, e) => {
    statuses.push(e)
    return { value: undefined }
  })
  engine(on, () => ({ exitCode: 0, stdout: JSON.stringify(REPORT), stderr: '' }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(2000)

  expect(statuses).toEqual([])
})

test('Exportar JSON runs the export command and shows where it wrote', async ($, on) => {
  const clock = mock.clock(on)
  const calls = engine(on, argv =>
    argv[1] === 'export'
      ? { exitCode: 0, stdout: '/tmp/sid-1.tooltrail.json\n', stderr: '' }
      : { exitCode: 0, stdout: JSON.stringify(REPORT), stderr: '' },
  )
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(2000)

  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  await ui.press({ key: 'export' })

  expect(calls).toContainEqual(['tooltrail', 'export', '--session', 'sid-1'])
  expect((await ui.find({ type: 'Text', text: /Exported/ }))?.text).toBe('Exported: /tmp/sid-1.tooltrail.json')
  await ui.unmount()
})

test('Sugerir limpieza lists what was loaded and never used', async ($, on) => {
  const clock = mock.clock(on)
  engine(on, () => ({ exitCode: 0, stdout: JSON.stringify(REPORT), stderr: '' }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(2000)

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /revenuecat/ })).toBeUndefined()
  await ui.press({ key: 'cleanup' })

  expect((await ui.find({ type: 'Text', text: /revenuecat/ }))?.text).toBe('  MCP revenuecat')
  await ui.unmount()
})

test('each button has a one-letter hotkey shown in its label', async ($, on) => {
  const clock = mock.clock(on)
  engine(on, () => ({ exitCode: 0, stdout: JSON.stringify(REPORT), stderr: '' }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(2000)

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  for (const [key, hotkey, label] of [
    ['note', 'n', 'n: Nota Obsidian'],
    ['export', 'e', 'e: Exportar JSON'],
    ['cleanup', 'c', 'c: Sugerir limpieza'],
  ]) {
    const button = await ui.find({ type: 'Button', key })
    expect(button?.props.hotkey).toBe(hotkey)
    expect(button?.text).toBe(label)
  }
  await ui.unmount()
})

test('a CLI failure is shown instead of a report', async ($, on) => {
  const clock = mock.clock(on)
  engine(on, () => ({ exitCode: 1, stdout: '', stderr: 'Error: no transcript for session sid-1\n' }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(2000)

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await ui.find({ type: 'Text', text: /no transcript/ }))?.text).toBe('Error: no transcript for session sid-1')
  expect((await ui.find({ type: 'Text', text: /No report yet/ }))?.text).toBe('No report yet.')
  await ui.unmount()
})

test('a failed run backs off for 30 s, then tries again', async ($, on) => {
  const clock = mock.clock(on)
  const calls = engine(on, () => ({ exitCode: 1, stdout: '', stderr: 'Error: boom\n' }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  await clock.advance(2000)
  expect(calls.length).toBe(1)
  await clock.advance(20000)
  expect(calls.length).toBe(1)
  await clock.advance(12000)
  expect(calls.length).toBe(2)
})

test('a binary that cannot start shows its error on the button press', async ($, on) => {
  const clock = mock.clock(on)
  on('session.id', () => ({ value: 'sid-1' }))
  on('command.register', () => ({ value: { command: 'tooltrail' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('process.run', (_, e) => {
    if (e.argv[1] === 'export') return { deny: 'spawn tooltrail ENOENT' }
    return { value: { exitCode: 0, stdout: JSON.stringify(REPORT), stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(2000)

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'export' })

  expect((await ui.find({ type: 'Text', text: /ENOENT/ }))?.text).toContain('tooltrail:')
  await ui.unmount()
})

test('Nota Obsidian passes the configured vault', { options: { vault: '/vault' } }, async ($, on) => {
  const clock = mock.clock(on)
  const calls = engine(on, argv =>
    argv[1] === 'note'
      ? { exitCode: 0, stdout: '/vault/ToolTrail/2026-11-11 sid-1.md\n', stderr: '' }
      : { exitCode: 0, stdout: JSON.stringify(REPORT), stderr: '' },
  )
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(2000)

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'note' })

  expect(calls).toContainEqual(['tooltrail', 'note', '--vault', '/vault', '--session', 'sid-1'])
  await ui.unmount()
})

test('a truncated report is reported, not parsed', async ($, on) => {
  const clock = mock.clock(on)
  on('session.id', () => ({ value: 'sid-1' }))
  on('command.register', () => ({ value: { command: 'tooltrail' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: '{"items":[', stderr: '', isStdoutTruncated: true, isStderrTruncated: false } }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(2000)

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await ui.find({ type: 'Text', text: /too large/ }))?.text).toBe('tooltrail: report too large to read')
  await ui.unmount()
})

test('formatters match the CLI formats', () => {
  expect(formatShare(0)).toBe('0%')
  expect(formatShare(0.004)).toBe('<1%')
  expect(formatShare(0.184)).toBe('18%')
  expect(formatUnits(780)).toBe('780')
  expect(formatUnits(23790)).toBe('23.8k')
  expect(formatUnits(1_200_000)).toBe('1.2M')
  expect(formatPoints(0)).toBe('0.0')
  expect(formatPoints(0.04)).toBe('<0.1')
  expect(formatPoints(0.44)).toBe('0.4')
  expect(formatWindows({ fiveHour: 2 })).toBe('5h +2.0 pp · 7d —')
})

test('summarize ranks by weighted units; totals omit the window without a baseline', () => {
  expect(summarize({ ...REPORT, items: [] })).toBe('tooltrail: no tools yet')
  expect(summarize(REPORT)).toBe('tooltrail: Explore×1 50% · firecrawl×6 20% · Bash×4 <1%')
  expect(describeTotals({ ...REPORT, windowDelta: undefined })).toBe('attributed 75% of 20.0k units')
  expect(describeTotals({ ...REPORT, sessionWeighted: 0, attributedWeighted: 0 })).toBe(
    'attributed 0% of 0 units · 5h +2.0 pp · 7d +0.5 pp (est.)',
  )
})
