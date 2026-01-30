import http from 'node:http'

import { fail, notFound, ok } from '../shared/response'
import { parseUrl } from '../utils/http-utils'

import { routes, type AppEnv } from './routes'

export function createApp(env: AppEnv) {
  return http.createServer(async (req, res) => {
    try {
      const { pathname, query } = parseUrl(req.url)

      const handler = routes[pathname]
      if (!handler) return notFound(res)

      const ctx = { req, res, env, pathname, query }
      const data = await handler(ctx)

      return ok(res, data)
    } catch (e) {
      console.error('[geo-api] error', e)
      return fail(res, e)
    }
  })
}
