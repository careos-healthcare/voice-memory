/** True when running a Next.js production build in the browser. */
export function isProductionBuild(): boolean {
  return process.env.NODE_ENV === "production";
}

export function isDebugRoutePath(pathname: string): boolean {
  return pathname.startsWith("/debug");
}

/** Debug-only work must not run on normal product surfaces. */
export function shouldRunDebugAggregation(): boolean {
  if (typeof window === "undefined") return false;
  return isDebugRoutePath(window.location.pathname);
}
