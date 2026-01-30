import { once } from 'lodash-es'
import maxmind from 'maxmind'

export type GeoEnv = {
  dbCity: string | null
  dbAsn: string | null
}

type AnyReader = {
  get(ip: string): unknown
}

let cityReader: AnyReader | null = null
let asnReader: AnyReader | null = null

const initOnce = once(async (env: GeoEnv) => {
  if (!cityReader && env.dbCity)
    cityReader = (await maxmind.open(env.dbCity)) as unknown as AnyReader
  if (!asnReader && env.dbAsn) asnReader = (await maxmind.open(env.dbAsn)) as unknown as AnyReader
})

export async function getReadersOnce(env: GeoEnv) {
  await initOnce(env)
  return { cityReader, asnReader }
}
