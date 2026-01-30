import type { ServerResponse } from 'node:http'

import dayjs from 'dayjs'

import { ApiError } from './api-error'

export type ApiOk<T> = {
  ok: true
  data: T
  meta: {
    ts: string
  }
}

export type ApiFail = {
  ok: false
  error: {
    code: string
    message: string
    details: unknown
  }
  meta: {
    ts: string
  }
}

function writeJson(res: ServerResponse, status: number, body: unknown) {
  const json = JSON.stringify(body)
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' })
  res.end(json)
}

export function ok<T>(res: ServerResponse, data: T) {
  const body: ApiOk<T> = {
    ok: true,
    data,
    meta: { ts: dayjs().toISOString() },
  }
  return writeJson(res, 200, body)
}

export function fail(res: ServerResponse, err: unknown) {
  const e =
    err instanceof ApiError
      ? err
      : new ApiError({
          code: 'internal_error',
          message: 'Internal Error',
          status: 500,
          details: null,
          cause: err,
        })

  const body: ApiFail = {
    ok: false,
    error: {
      code: e.code,
      message: e.message,
      details: e.details ?? null,
    },
    meta: { ts: dayjs().toISOString() },
  }

  return writeJson(res, e.status, body)
}

export function notFound(res: ServerResponse) {
  const body: ApiFail = {
    ok: false,
    error: { code: 'not_found', message: 'Not Found', details: null },
    meta: { ts: dayjs().toISOString() },
  }
  return writeJson(res, 404, body)
}
