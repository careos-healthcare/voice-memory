/**
 * Edge-safe internal route gate — no server-only imports (middleware compatible).
 */

import type { NextRequest } from "next/server";

const INTERNAL_COOKIE = "vm_debug";
const DEPRECATED_DEBUG_PREFIX = "/debug";
const TIER1_DEV_PREFIXES = ["/demo"] as const;
const TIER2_INTERNAL_PREFIXES = ["/internal", "/launch"] as const;

export function isDevelopmentRuntime(): boolean {
  return process.env.NODE_ENV === "development";
}

export function isFounderModeEnabled(): boolean {
  return process.env.FOUNDER_MODE === "true";
}

export function isInternalSurfaceEnabled(): boolean {
  if (!isFounderModeEnabled()) return false;
  if (isDevelopmentRuntime()) {
    return process.env.VOICEMEMORY_ENABLE_INTERNAL !== "false";
  }
  return process.env.VOICEMEMORY_ENABLE_INTERNAL === "true";
}

export function debugAccessToken(): string | null {
  return process.env.DEBUG_ACCESS_TOKEN?.trim() || null;
}

export function readRequestAccessToken(request: NextRequest): string | null {
  const query = request.nextUrl.searchParams.get("debug_token")?.trim();
  if (query) return query;
  return request.cookies.get(INTERNAL_COOKIE)?.value?.trim() ?? null;
}

export function tokenMatchesConfigured(access: string | null): boolean {
  const expected = debugAccessToken();
  if (!expected || !access) return false;
  return access === expected;
}

export function isDeprecatedDebugPath(pathname: string): boolean {
  return (
    pathname === DEPRECATED_DEBUG_PREFIX ||
    pathname.startsWith(`${DEPRECATED_DEBUG_PREFIX}/`)
  );
}

export function isTier2Path(pathname: string): boolean {
  return TIER2_INTERNAL_PREFIXES.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  );
}

export function isTier1Path(pathname: string): boolean {
  return TIER1_DEV_PREFIXES.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  );
}

export function evaluateTier1DevRoute(pathname: string): {
  allow: boolean;
  reason: string;
} {
  const isTier1 = TIER1_DEV_PREFIXES.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  );
  if (!isTier1) return { allow: false, reason: "not_tier1" };
  if (!isDevelopmentRuntime()) {
    return { allow: false, reason: "tier1_production_denied" };
  }
  return { allow: true, reason: "tier1_dev" };
}

export function evaluateTier2InternalRouteEdge(request: NextRequest): {
  allow: boolean;
  reason: string;
} {
  if (!isInternalSurfaceEnabled()) {
    return { allow: false, reason: "internal_disabled" };
  }
  if (!debugAccessToken()) {
    return { allow: false, reason: "token_unconfigured" };
  }
  if (tokenMatchesConfigured(readRequestAccessToken(request))) {
    return { allow: true, reason: "token" };
  }
  return { allow: false, reason: "unauthorized" };
}

export { INTERNAL_COOKIE };
