import { geoRoutes } from './geo.routes'
import { healthRoutes } from './health.routes'
import type { RouteHandler } from './route.types'

export const routes: Record<string, RouteHandler> = {
  ...healthRoutes,
  ...geoRoutes,
}

export type { AppEnv, RouteCtx, RouteHandler } from './route.types'
