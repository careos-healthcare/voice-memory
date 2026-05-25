import { NextResponse } from "next/server";

import type { SyncErrorCode } from "@/types/sync-errors";

export function syncApiSuccess<T extends Record<string, unknown>>(
  data: T,
  status = 200,
): NextResponse {
  return NextResponse.json({ ok: true, ...data }, { status });
}

export function syncApiFailure(
  error: string,
  code: SyncErrorCode | string,
  status = 400,
): NextResponse {
  return NextResponse.json({ ok: false, error, code }, { status });
}

export function syncApiUnauthorized(): NextResponse {
  return syncApiFailure("Sign in required.", "SYNC_AUTH_REQUIRED", 401);
}
