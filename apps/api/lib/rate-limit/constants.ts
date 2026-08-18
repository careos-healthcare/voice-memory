export const GLOBAL_RATE_LIMIT_WINDOW_MS = 60_000;
export const GLOBAL_RATE_LIMIT_MAX_REQUESTS = 120;

export const GLOBAL_RATE_LIMIT_EXEMPT_PATHS = new Set([
  "/api/health",
  "/api/healthz",
]);

export function shouldApplyGlobalRateLimit(pathname: string): boolean {
  if (!pathname.startsWith("/api/")) return false;
  return !GLOBAL_RATE_LIMIT_EXEMPT_PATHS.has(pathname);
}
