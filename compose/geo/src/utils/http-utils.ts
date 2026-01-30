import { URL } from 'node:url'

import { isNil } from 'lodash-es'

export function parseUrl(urlStr: string | undefined) {
  const u = new URL(urlStr ?? '/', 'http://localhost')
  const query: Record<string, string> = {}

  for (const [k, v] of u.searchParams.entries()) {
    if (!isNil(v) && v !== '') query[k] = v
  }

  return { pathname: u.pathname, query }
}
