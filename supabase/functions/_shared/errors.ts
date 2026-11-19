import { corsHeaders } from './cors.ts';

/**
 * Standardized JSON error response per PRD Section 21:
 * { "error": "code", "message": "description" }
 */
export function jsonError(
  status: number,
  code: string,
  message: string,
  extra?: Record<string, unknown>,
): Response {
  return new Response(
    JSON.stringify({
      error: code,
      message,
      ...(extra ?? {}),
    }),
    {
      status,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
      },
    },
  );
}

export function jsonOk(status: number, data: Record<string, unknown>): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}
