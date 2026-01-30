import { isFinite } from 'lodash-es'

import { createApp } from './app/create-app'
import type { AppEnv } from './app/routes'

function readEnv(): AppEnv {
  const portRaw = Number(process.env.PORT ?? 9010)
  const port = isFinite(portRaw) ? portRaw : 9010

  return {
    port,
    dbCity: process.env.GEOIP_DB_CITY || null,
    dbAsn: process.env.GEOIP_DB_ASN || null,
  }
}

const env = readEnv()
const server = createApp(env)

server.listen(env.port, '0.0.0.0', () => {
  console.log(`[geo-api] listening on :${env.port}`)
})

function shutdown(signal: string) {
  console.log(`[geo-api] shutdown (${signal})`)
  server.close(() => process.exit(0))
  setTimeout(() => process.exit(1), 3000).unref()
}

process.on('SIGINT', () => shutdown('SIGINT'))
process.on('SIGTERM', () => shutdown('SIGTERM'))
