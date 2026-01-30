import type { RouteHandler } from './route.types'

export const healthRoutes: Record<string, RouteHandler> = {
  '/health': async () => {
    return { ok: true }
  },
}
