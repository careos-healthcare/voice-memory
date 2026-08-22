/**
 * Web production route contract — marketing, legal, support, and beta only.
 * The Flutter mobile app is the consumer product; web does not host capture/archive UI.
 */

/** Routes that may be served publicly in production. */
export const WEB_PUBLIC_PRODUCTION_ROUTES = [
  "/",
  "/welcome",
  "/beta",
  "/privacy",
  "/terms",
  "/contact",
  "/safety",
] as const;

export type WebPublicProductionRoute = (typeof WEB_PUBLIC_PRODUCTION_ROUTES)[number];

/** Deterministic redirects where a real equivalent exists. */
export const WEB_PUBLIC_REDIRECTS: Readonly<Record<string, string>> = {
  "/privacy-simple": "/privacy",
  "/support": "/contact",
};

/**
 * Retired consumer product paths — middleware returns 404 (gone from web).
 * Kept for crawler tests and documentation; not served in production.
 */
export const RETIRED_CONSUMER_ROUTE_PREFIXES = [
  "/account",
  "/archive",
  "/archive-belief",
  "/archive-detail",
  "/blind-spots",
  "/bookmarks",
  "/creator-kit",
  "/creator-preview",
  "/discover",
  "/entry",
  "/export",
  "/feelings-timeline",
  "/how-it-works",
  "/insights",
  "/intentions",
  "/invite",
  "/journal",
  "/memory",
  "/monthly",
  "/offline",
  "/open-loops",
  "/pilot",
  "/pricing",
  "/record",
  "/reminders",
  "/roundups",
  "/search",
  "/seasons",
  "/settings",
  "/territories",
  "/theories",
  "/threads",
  "/timeline",
  "/updates",
  "/weekly",
] as const;

export function normalizePathname(pathname: string): string {
  if (!pathname || pathname === "/") return "/";
  const trimmed = pathname.replace(/\/+$/, "") || "/";
  return trimmed.startsWith("/") ? trimmed : `/${trimmed}`;
}

export function isPublicProductionPath(pathname: string): boolean {
  const path = normalizePathname(pathname);
  return (WEB_PUBLIC_PRODUCTION_ROUTES as readonly string[]).includes(path);
}

export function resolvePublicRedirect(pathname: string): string | null {
  const path = normalizePathname(pathname);
  return WEB_PUBLIC_REDIRECTS[path] ?? null;
}

export function isRetiredConsumerPath(pathname: string): boolean {
  const path = normalizePathname(pathname);
  if (isPublicProductionPath(path)) return false;
  return RETIRED_CONSUMER_ROUTE_PREFIXES.some(
    (prefix) => path === prefix || path.startsWith(`${prefix}/`),
  );
}

export function isWebMarketingNavHref(href: string): boolean {
  const path = normalizePathname(href.split("#")[0] ?? href);
  return isPublicProductionPath(path) || resolvePublicRedirect(path) !== null;
}
