import type { IncomingMessage, ServerResponse } from 'node:http'

import { ApiErrors } from '../../shared/api-error'
import { pickClientIp } from '../../utils/ip-utils'
import { normalizeAsn, normalizeCity } from '../normalizers'
import { getReadersOnce, type GeoEnv } from '../readers'

export type RouteCtx = {
  req: IncomingMessage
  res: ServerResponse
  env: GeoEnv
  pathname: string
  query: Record<string, string>
}

export async function geoMeRoute(ctx: RouteCtx) {
  const ip = pickClientIp(ctx.req)
  if (!ip) throw ApiErrors.badRequest('cannot_pick_ip', 'Cannot pick client IP')
  return geoLookup(ctx, ip)
}

export async function geoIpRoute(ctx: RouteCtx) {
  const ip = ctx.query.ip ?? null
  if (!ip) throw ApiErrors.badRequest('missing_ip', 'Missing query param: ip')
  return geoLookup(ctx, ip)
}

async function geoLookup(ctx: RouteCtx, ip: string) {
  const { cityReader, asnReader } = await getReadersOnce(ctx.env)

  const cityRaw = cityReader ? cityReader.get(ip) : null
  const asnRaw = asnReader ? asnReader.get(ip) : null

  return {
    ip,
    geo: normalizeCity(cityRaw),
    asn: normalizeAsn(asnRaw),
    meta: {
      hasCityDb: Boolean(ctx.env.dbCity),
      hasAsnDb: Boolean(ctx.env.dbAsn),
    },
  }
}
