import type { IncomingMessage } from 'node:http'

export function pickClientIp(req: IncomingMessage): string | null {
  const h = req.headers
  const xff = h['x-forwarded-for']
  const cf = h['cf-connecting-ip']
  const xr = h['x-real-ip']

  const raw =
    (typeof cf === 'string' && cf) ||
    (typeof xr === 'string' && xr) ||
    (typeof xff === 'string' && xff.split(',')[0]?.trim()) ||
    ''

  return raw || null
}
