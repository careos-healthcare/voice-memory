import { NextResponse } from "next/server";

export const EPHEMERAL_AI_HEADERS = {
  "Cache-Control": "private, no-store, no-cache, must-revalidate, max-age=0",
  Pragma: "no-cache",
  Expires: "0",
  "X-Content-Type-Options": "nosniff",
} as const;

export function ephemeralAiJson(
  body: unknown,
  init?: ResponseInit,
): NextResponse {
  return NextResponse.json(body, {
    ...init,
    headers: {
      ...EPHEMERAL_AI_HEADERS,
      ...init?.headers,
    },
  });
}

export function logEphemeralAiFailure(route: string, error: unknown): void {
  const safe = error as { name?: unknown; status?: unknown; code?: unknown };
  console.error("Ephemeral AI request failed", {
    route,
    errorName: typeof safe?.name === "string" ? safe.name : "UnknownError",
    status: typeof safe?.status === "number" ? safe.status : undefined,
    code: typeof safe?.code === "string" ? safe.code : undefined,
  });
}
