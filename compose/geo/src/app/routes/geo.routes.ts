import { geoIpRoute, geoMeRoute } from '../../geo/routes/geo'

import type { RouteHandler } from './route.types'

export const geoRoutes: Record<string, RouteHandler> = {
  '/geo/me': geoMeRoute,
  '/geo/ip': geoIpRoute,
}
