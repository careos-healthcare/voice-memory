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
  "/blind-spots",
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
  "apps/web/app/timeline/page.tsx",
  "apps/web/app/feelings-timeline/page.tsx",
  "apps/web/app/intentions/page.tsx",
  "apps/web/app/roundups/page.tsx",
  "apps/web/app/territories/page.tsx",
  "apps/web/app/seasons/page.tsx",
  "apps/web/app/bookmarks/page.tsx",
  "apps/web/app/open-loops/page.tsx",
  "apps/web/app/blind-spots/page.tsx",
  "apps/web/app/export/print/page.tsx",
];

/** Dynamic segment routes — tested via test:a11y:dynamic + seed fixture */
export const DYNAMIC_PAGE_FILES = [
  "apps/web/app/entry/[id]/page.tsx",
  "apps/web/app/threads/[slug]/page.tsx",
  "apps/web/app/territories/[slug]/page.tsx",
  "apps/web/app/roundups/[period]/page.tsx",
];

export const TIER_C_PAGE_FILES = [
  "apps/web/app/privacy/page.tsx",
  "apps/web/app/privacy-simple/page.tsx",
  "apps/web/app/terms/page.tsx",
  "apps/web/app/contact/page.tsx",
  "apps/web/app/safety/page.tsx",
  "apps/web/app/how-it-works/page.tsx",
  "apps/web/app/offline/page.tsx",
  "apps/web/app/welcome/page.tsx",
];
