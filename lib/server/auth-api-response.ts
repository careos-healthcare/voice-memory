import { NextResponse } from "next/server";

import type { AuthErrorCode } from "@/types/auth-errors";

export function authApiSuccess<T extends Record<string, unknown>>(
  data: T,
  status = 200,
): NextResponse {
  return NextResponse.json({ ok: true, ...data }, { status });
}

export function authApiFailure(
  error: string,
  code: AuthErrorCode | string,
  status = 400,
): NextResponse {
  return NextResponse.json({ ok: false, error, code }, { status });
}
