/**
 * Canonical accessibility route tiers — keep in sync with scripts/generate-accessibility-tier-map.mjs
 */

/** Launch-critical core loop */
export const TIER_A_ROUTES = [
  "/",
  "/record",
  "/journal",
  "/memory",
  "/threads",
  "/archive",
  "/pricing",
  "/account",
  "/export",
  "/settings",
  "/search",
  "/reminders",
] as const;

/** Secondary discovery / depth surfaces */
export const TIER_B_ROUTES = [
  "/weekly",
  "/monthly",
  "/insights",
  "/timeline",
  "/feelings-timeline",
  "/intentions",
  "/roundups",
  "/roundups/week",
  "/territories",
  "/seasons",
  "/bookmarks",
  "/open-loops",
  "/export/print",
] as const;

/** Legal, trust, onboarding static */
export const TIER_C_ROUTES = [
  "/privacy",
  "/privacy-simple",
  "/terms",
  "/contact",
  "/safety",
  "/how-it-works",
  "/offline",
  "/welcome",
] as const;

/** Locked founder/internal — unauthorized state only */
export const TIER_D_LOCKED_SAMPLES = [
  "/internal/founder-review",
  "/internal/entitlements",
  "/debug/founder-review",
] as const;

/** Retired, dev-only, or non-public */
export const EXCLUDED_ROUTES = [
  "/demo",
  "/launch",
  "/pilot",
  "/invite",
  "/creator-preview",
] as const;

/** All public launchable routes in strict WCAG gate */
export const LAUNCH_SURFACE_ROUTES = [
  ...TIER_A_ROUTES,
  ...TIER_B_ROUTES,
  ...TIER_C_ROUTES,
] as const;
