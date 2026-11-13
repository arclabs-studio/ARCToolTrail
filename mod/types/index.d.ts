export type TrailCategory = 'skill' | 'mcp' | 'plugin' | 'subagent' | 'builtin'

export type TrailTokens = {
  input: number
  output: number
  cacheRead: number
  cacheWrite5m: number
  cacheWrite1h: number
}

/** Percentage points of the 5-hour and 7-day rate-limit windows. */
export type TrailWindows = { fiveHour?: number; sevenDay?: number }

export type TrailItem = {
  identity: {
    category: TrailCategory
    name: string
    plugin?: string
    server?: string
    isConnector: boolean
  }
  uses: number
  usesInSubagents: number
  firstUse?: string
  lastUse?: string
  attributedTokens: TrailTokens
  estimatedCostUSD?: number
  /** Attributed tokens in price-weighted units (1 = one input token). */
  weighted: number
  /** weighted / sessionWeighted. */
  sessionShare: number
  weightedPerUse: number
  /** Raw tokens later calls re-read because of this tool's results. */
  contextCarry: number
  liveContextTokens: number
  /** Share of the context window this tool added since the last compaction. */
  liveContextShare?: number
  /** Estimated window points (session window use × sessionShare). */
  windowPoints?: TrailWindows
}

export type TrailCleanup = { kind: 'mcpServer' | 'plugin'; name: string }

/** `tooltrail report --json` output (the fields the mod reads). */
export type TrailReport = {
  sessionId: string
  generatedAt: string
  items: TrailItem[]
  sessionCostUSD?: number
  attributedCostUSD?: number
  costSource: 'costState' | 'priceTable' | 'unavailable'
  cleanup: TrailCleanup[]
  sessionTokens: TrailTokens
  sessionWeighted: number
  attributedWeighted: number
  /** Window points used while the session ran (parallel sessions included). */
  windowDelta?: TrailWindows
  contextWindowSize?: number
}

export type TrailView = {
  /** Last report, or null before the first one. */
  report: TrailReport | null
  /** Last CLI error or action result shown under the table. */
  message: string
  showCleanup: boolean
}

declare module 'claude-code' {
  interface PluginState {
    'arc-tooltrail': { view: Shaped<TrailView> }
  }
}
