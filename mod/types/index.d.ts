export type TrailCategory = 'skill' | 'mcp' | 'plugin' | 'subagent' | 'builtin'

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
  estimatedCostUSD?: number
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
