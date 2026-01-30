import type { IncomingMessage, ServerResponse } from 'node:http'

export type AppEnv = {
  port: number
  dbCity: string | null
  dbAsn: string | null
}

export type RouteCtx = {
  req: IncomingMessage
  res: ServerResponse
  env: AppEnv
  pathname: string
  query: Record<string, string>
}

export type RouteHandler = (ctx: RouteCtx) => Promise<unknown>
