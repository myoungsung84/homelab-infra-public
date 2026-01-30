export type ApiErrorShape = {
  code: string
  message: string
  details?: unknown
}

export class ApiError extends Error {
  readonly code: string
  readonly status: number
  readonly details: unknown

  constructor(args: {
    code: string
    message: string
    status: number
    details?: unknown
    cause?: unknown
  }) {
    super(args.message)
    this.name = 'ApiError'
    this.code = args.code
    this.status = args.status
    this.details = args.details ?? null
    if (args.cause) (this as any).cause = args.cause
  }

  toJSON(): ApiErrorShape {
    return {
      code: this.code,
      message: this.message,
      details: this.details ?? null,
    }
  }
}

export const ApiErrors = {
  badRequest(code: string, message: string, details?: unknown) {
    return new ApiError({ code, message, status: 400, details })
  },
  notFound(code: string, message: string, details?: unknown) {
    return new ApiError({ code, message, status: 404, details })
  },
  internal(code: string, message = 'Internal Error', details?: unknown, cause?: unknown) {
    return new ApiError({ code, message, status: 500, details, cause })
  },
} as const
