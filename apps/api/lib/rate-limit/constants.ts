export const GLOBAL_RATE_LIMIT_WINDOW_MS = 60_000;
export const GLOBAL_RATE_LIMIT_MAX_REQUESTS = 120;

/**
 * Paths the global limiter never touches.
 *
 * `/api/coach/consent/revoke` is here because a failed revoke is worse than an
 * extra one. Two ways the limiter would otherwise stand between a user and
 * ending someone's access to their journal: a burst of retries from a queued
 * offline revoke could exhaust the window, and
 * `enforceGlobalRateLimitForNodeRequest` throws — turning into a 503 for every
 * limited path — whenever Redis is unavailable in production. Neither is an
 * acceptable reason for access to persist. The route is session-gated and does
 * one idempotent upsert.
 */
export const GLOBAL_RATE_LIMIT_EXEMPT_PATHS = new Set([
  "/api/health",
  "/api/healthz",
  "/api/coach/consent/revoke",
]);

export function shouldApplyGlobalRateLimit(pathname: string): boolean {
  if (!pathname.startsWith("/api/")) return false;
  return !GLOBAL_RATE_LIMIT_EXEMPT_PATHS.has(pathname);
}
