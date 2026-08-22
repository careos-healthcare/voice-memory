import "server-only";

import type { NextRequest } from "next/server";

import { debugAccessToken, isFounderEmail } from "@/lib/server/founder-access";
import { isFounderModeEnabled } from "@/lib/server/founder-mode";
import { getServerSession } from "@/lib/server/session";
import { logInternalAccessEvent } from "@/lib/server/internal-access-log";

export const INTERNAL_COOKIE = "vm_debug";
export const DEPRECATED_DEBUG_PREFIX = "/debug";

/** Tier 1 — local dev only (never in production). */
export const TIER1_DEV_PREFIXES = ["/demo"] as const;

/** Tier 2 — founder internal tooling. */
export const TIER2_INTERNAL_PREFIXES = ["/internal", "/launch"] as const;

export function isDevelopmentRuntime(): boolean {
  return process.env.NODE_ENV === "development";
}

export function isInternalSurfaceEnabled(): boolean {
  if (!isFounderModeEnabled()) return false;
  if (isDevelopmentRuntime()) {
    return process.env.VOICEMEMORY_ENABLE_INTERNAL !== "false";
  }
  return process.env.VOICEMEMORY_ENABLE_INTERNAL === "true";
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

export async function hasFounderSession(): Promise<boolean> {
  const session = await getServerSession();
  if (!session?.email) return false;
  return isFounderEmail(session.email);
}

export type InternalAccessDecision =
  | { allow: true; via: "dev" | "token" | "founder" }
  | { allow: false; reason: string };

/** Middleware decision for tier-1 dev-only paths. */
export function evaluateTier1DevRoute(pathname: string): InternalAccessDecision {
  const isTier1 = TIER1_DEV_PREFIXES.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  );
  if (!isTier1) return { allow: false, reason: "not_tier1" };
  if (!isDevelopmentRuntime()) {
    return { allow: false, reason: "tier1_production_denied" };
  }
  return { allow: true, via: "dev" };
}

/** Edge-safe tier-2 gate — token cookie/query only (founder session verified in RSC layout). */
export function evaluateTier2InternalRouteEdge(
  request: NextRequest,
): InternalAccessDecision {
  if (!isInternalSurfaceEnabled()) {
    return { allow: false, reason: "internal_disabled" };
  }

  const token = debugAccessToken();
  if (!token) {
    return { allow: false, reason: "token_unconfigured" };
  }

  const access = readRequestAccessToken(request);
  if (tokenMatchesConfigured(access)) {
    return { allow: true, via: "token" };
  }

  return { allow: false, reason: "unauthorized" };
}

export function isTier2Path(pathname: string): boolean {
  return TIER2_INTERNAL_PREFIXES.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  );
}

export function isDeprecatedDebugPath(pathname: string): boolean {
  return (
    pathname === DEPRECATED_DEBUG_PREFIX ||
    pathname.startsWith(`${DEPRECATED_DEBUG_PREFIX}/`)
  );
}

export async function recordInternalAccessAttempt(
  request: NextRequest,
  outcome: "allowed" | "denied",
  detail: string,
): Promise<void> {
  await logInternalAccessEvent({
    pathname: request.nextUrl.pathname,
    method: request.method,
    outcome,
    detail,
    ipHash: request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown",
  });
}
