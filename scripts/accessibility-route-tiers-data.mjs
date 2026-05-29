/** Shared route tier data — mirrored in e2e/helpers/accessibility-routes.ts */

export const TIER_A = [
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
];

export const TIER_B = [
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
];

export const TIER_C = [
  "/privacy",
  "/privacy-simple",
  "/terms",
  "/contact",
  "/safety",
  "/how-it-works",
  "/offline",
  "/welcome",
];

export const TIER_D_LOCKED = [
  "/internal/founder-review",
  "/internal/entitlements",
  "/debug/founder-review",
];

export const EXCLUDED = ["/demo", "/launch", "/pilot", "/invite", "/creator-preview"];

export const LAUNCH_SURFACE = [...TIER_A, ...TIER_B, ...TIER_C];

/** app/ path for static PrimaryMain checks */
export const TIER_B_PAGE_FILES = [
  "app/timeline/page.tsx",
  "app/feelings-timeline/page.tsx",
  "app/intentions/page.tsx",
  "app/roundups/page.tsx",
  "app/territories/page.tsx",
  "app/seasons/page.tsx",
  "app/bookmarks/page.tsx",
  "app/open-loops/page.tsx",
  "app/export/print/page.tsx",
];

/** Dynamic segment routes — tested via test:a11y:dynamic + seed fixture */
export const DYNAMIC_PAGE_FILES = [
  "app/entry/[id]/page.tsx",
  "app/threads/[slug]/page.tsx",
  "app/territories/[slug]/page.tsx",
  "app/roundups/[period]/page.tsx",
];

export const TIER_C_PAGE_FILES = [
  "app/privacy/page.tsx",
  "app/privacy-simple/page.tsx",
  "app/terms/page.tsx",
  "app/contact/page.tsx",
  "app/safety/page.tsx",
  "app/how-it-works/page.tsx",
  "app/offline/page.tsx",
  "app/welcome/page.tsx",
];
