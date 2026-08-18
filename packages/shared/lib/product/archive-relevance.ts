/**
 * Surface Reduction v2 — prominence only when a surface answers the four archive questions.
 */
import { productQuestionForRoute } from "@/lib/product/archive-product-questions";

export type ArchiveRelevanceLevel = "core" | "supporting" | "utility" | "internal";

export interface SurfaceClassification {
  route: string;
  purpose: string;
  level: ArchiveRelevanceLevel;
  keep: boolean;
  merge: string | null;
  hide: boolean;
  reason: string;
}

/** Routes that stay in primary navigation. */
export const CORE_PRIMARY_ROUTES = [
  "/",
  "/record",
  "/archive-belief",
  "/discover",
  "/account",
] as const;

export const ARCHIVE_DETAIL_HUB_ROUTE = "/archive-detail";

const ROUTE_META: Array<{
  route: string;
  purpose: string;
  level: ArchiveRelevanceLevel;
  merge?: string | null;
  hide?: boolean;
  reason: string;
}> = [
  {
    route: "/archive-belief",
    purpose: "What the archive currently believes and why to trust it",
    level: "core",
    reason: "Answers belief, evidence, and trust in one screen",
  },
  {
    route: "/discover",
    purpose: "What changed since last visit",
    level: "core",
    reason: "Answers what changed and movement",
  },
  {
    route: "/",
    purpose: "Record reflections",
    level: "core",
    reason: "Adds evidence — entry point to the archive",
  },
  {
    route: "/record",
    purpose: "Record reflections",
    level: "core",
    reason: "Adds evidence",
  },
  {
    route: "/account",
    purpose: "Account, backup, archive detail access",
    level: "core",
    reason: "Operational home; links to archive detail",
  },
  {
    route: ARCHIVE_DETAIL_HUB_ROUTE,
    purpose: "Secondary archive tools in one hub",
    level: "supporting",
    reason: "Demoted features — dossier, locker, accuracy, log, search",
  },
  {
    route: "/memory",
    purpose: "Reflection log — entries only",
    level: "utility",
    merge: ARCHIVE_DETAIL_HUB_ROUTE,
    reason: "Storage only; archive owns interpretation",
  },
  {
    route: "/search",
    purpose: "Search evidence in reflections",
    level: "utility",
    merge: ARCHIVE_DETAIL_HUB_ROUTE,
    hide: true,
    reason: "Operational search — not primary nav",
  },
  {
    route: "/blind-spots",
    purpose: "Pattern review / archive insight",
    level: "supporting",
    merge: ARCHIVE_DETAIL_HUB_ROUTE,
    hide: true,
    reason: "Supports why the archive believes — not primary",
  },
  {
    route: "/theories",
    purpose: "Archive beliefs list",
    level: "supporting",
    merge: ARCHIVE_DETAIL_HUB_ROUTE,
    hide: true,
    reason: "Merged into archive detail; belief lives on Archive",
  },
  {
    route: "/updates",
    purpose: "Change feed",
    level: "supporting",
    merge: "/discover",
    hide: true,
    reason: "Discover owns change",
  },
  {
    route: "/insights",
    purpose: "Legacy insights",
    level: "utility",
    merge: ARCHIVE_DETAIL_HUB_ROUTE,
    hide: true,
    reason: "Demoted legacy surface",
  },
  {
    route: "/journal",
    purpose: "Journal timeline",
    level: "utility",
    merge: ARCHIVE_DETAIL_HUB_ROUTE,
    hide: true,
    reason: "Operational log variant",
  },
  {
    route: "/timeline",
    purpose: "Belief timeline",
    level: "supporting",
    merge: ARCHIVE_DETAIL_HUB_ROUTE,
    hide: true,
    reason: "Shows how beliefs changed — detail hub",
  },
  {
    route: "/export",
    purpose: "Export archive",
    level: "utility",
    reason: "Operational export",
  },
  {
    route: "/pricing",
    purpose: "Subscription",
    level: "utility",
    reason: "Billing",
  },
  {
    route: "/weekly",
    purpose: "Weekly roundup",
    level: "utility",
    merge: ARCHIVE_DETAIL_HUB_ROUTE,
    hide: true,
    reason: "Demoted utility",
  },
  {
    route: "/monthly",
    purpose: "Monthly roundup",
    level: "utility",
    merge: ARCHIVE_DETAIL_HUB_ROUTE,
    hide: true,
    reason: "Demoted utility",
  },
];

function normalizeRoute(pathname: string): string {
  const path = pathname.split("?")[0]?.split("#")[0] ?? pathname;
  if (path === "/" || path.startsWith("/#")) return "/";
  if (path.startsWith("/entry/")) return "/memory";
  if (path.startsWith("/internal") || path.startsWith("/debug")) return path;
  for (const { route } of ROUTE_META) {
    if (path === route || path.startsWith(`${route}/`)) return route;
  }
  return path;
}

export function classifySurface(pathname: string): SurfaceClassification {
  const route = normalizeRoute(pathname);

  if (route.startsWith("/internal") || route.startsWith("/debug")) {
    return {
      route,
      purpose: "Founder / engineering",
      level: "internal",
      keep: false,
      merge: null,
      hide: true,
      reason: "Internal only",
    };
  }

  const meta = ROUTE_META.find((m) => m.route === route);
  if (meta) {
    return {
      route: meta.route,
      purpose: meta.purpose,
      level: meta.level,
      keep: meta.level === "core",
      merge: meta.merge ?? null,
      hide: meta.hide ?? meta.level !== "core",
      reason: meta.reason,
    };
  }

  const q = productQuestionForRoute(route);
  const level: ArchiveRelevanceLevel =
    q.role === "primary"
      ? "core"
      : q.role === "supporting"
        ? "supporting"
        : q.role === "utility"
          ? "utility"
          : "internal";

  return {
    route,
    purpose: q.productQuestion ?? "Other product surface",
    level,
    keep: level === "core",
    merge: level === "core" ? null : ARCHIVE_DETAIL_HUB_ROUTE,
    hide: level !== "core",
    reason:
      q.productQuestion != null
        ? `Maps to archive question: ${q.productQuestion}`
        : "Utility or unspecified — demote to archive detail",
  };
}

export interface ArchiveRelevanceReport {
  generatedAt: string;
  rows: SurfaceClassification[];
  coreCount: number;
  lines: string[];
}

export function buildArchiveRelevanceReport(
  routes = ROUTE_META.map((m) => m.route),
): ArchiveRelevanceReport {
  const generatedAt = new Date().toISOString();
  const rows = routes.map((route) => classifySurface(route));
  const coreCount = rows.filter((r) => r.level === "core").length;

  const lines = [
    `Generated ${generatedAt}`,
    `Core surfaces: ${coreCount}`,
    "Primary journey: Record → Archive → Archive Changes → Account",
    "Secondary: Archive Detail hub",
  ];

  return { generatedAt, rows, coreCount, lines };
}

export function isCorePrimaryRoute(pathname: string): boolean {
  const route = normalizeRoute(pathname);
  return (CORE_PRIMARY_ROUTES as readonly string[]).includes(route);
}

export function isDemotedFromPrimaryNav(pathname: string): boolean {
  const c = classifySurface(pathname);
  return c.hide || c.level !== "core";
}
