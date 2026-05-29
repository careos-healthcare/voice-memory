import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

import {
  debugAccessToken,
  evaluateTier1DevRoute,
  evaluateTier2InternalRouteEdge,
  INTERNAL_COOKIE,
  isDeprecatedDebugPath,
  isTier1Path,
  isTier2Path,
  readRequestAccessToken,
  tokenMatchesConfigured,
} from "@/lib/middleware/internal-gate";

const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 120;
const rateBuckets = new Map<string, { count: number; resetAt: number }>();

function rateLimitKey(request: NextRequest): string {
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "local";
  return `${ip}:${request.nextUrl.pathname}`;
}

function isRateLimited(request: NextRequest): boolean {
  const key = rateLimitKey(request);
  const now = Date.now();
  const bucket = rateBuckets.get(key);
  if (!bucket || now > bucket.resetAt) {
    rateBuckets.set(key, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return false;
  }
  bucket.count += 1;
  return bucket.count > RATE_LIMIT_MAX;
}

function applyTokenCookieRedirect(request: NextRequest): NextResponse | null {
  const queryToken = request.nextUrl.searchParams.get("debug_token");
  const token = debugAccessToken();
  if (!queryToken || !token || queryToken !== token) return null;

  const url = request.nextUrl.clone();
  url.searchParams.delete("debug_token");
  const response = NextResponse.redirect(url);
  response.cookies.set(INTERNAL_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    maxAge: 60 * 60 * 8,
    path: "/",
  });
  return response;
}

function denyNotFound(): NextResponse {
  return new NextResponse(null, { status: 404 });
}

/** Deny-by-default; /debug permanently retired; /internal requires token + env flag. */
export function middleware(request: NextRequest) {
  const pathname = request.nextUrl.pathname;

  if (isDeprecatedDebugPath(pathname)) {
    return denyNotFound();
  }

  if (isTier1Path(pathname)) {
    const tier1 = evaluateTier1DevRoute(pathname);
    if (!tier1.allow) return denyNotFound();
    if (isRateLimited(request)) return denyNotFound();
    return NextResponse.next();
  }

  if (!isTier2Path(pathname)) {
    return NextResponse.next();
  }

  if (isRateLimited(request)) {
    return denyNotFound();
  }

  const cookieRedirect = applyTokenCookieRedirect(request);
  if (cookieRedirect) return cookieRedirect;

  const tier2 = evaluateTier2InternalRouteEdge(request);
  if (!tier2.allow) {
    return denyNotFound();
  }

  if (!tokenMatchesConfigured(readRequestAccessToken(request))) {
    return denyNotFound();
  }

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-vm-internal-path", pathname);
  requestHeaders.set("x-vm-internal-method", request.method);

  return NextResponse.next({
    request: { headers: requestHeaders },
  });
}

export const config = {
  matcher: [
    "/debug",
    "/debug/:path*",
    "/internal",
    "/internal/:path*",
    "/demo",
    "/demo/:path*",
    "/launch",
    "/launch/:path*",
  ],
};
