import { productQuestionForRoute } from "@/lib/product/archive-product-questions";
import type { ArchiveProductSurfaceRole } from "@/lib/product/archive-product-questions";
import { WEB_PUBLIC_PRODUCTION_ROUTES } from "@/lib/site/web-public-production-routes";

export type SurfaceAuditTier = ArchiveProductSurfaceRole;

export interface SurfaceAuditEntry {
  route: string;
  tier: SurfaceAuditTier;
  productQuestion: string | null;
  helpsArchiveUnderstanding: boolean;
  utilityOnly: boolean;
  label: string;
}

export interface SurfaceAuditReport {
  generatedAt: string;
  primary: SurfaceAuditEntry[];
  supporting: SurfaceAuditEntry[];
  utility: SurfaceAuditEntry[];
  internal: SurfaceAuditEntry[];
  directlyImprovesUnderstanding: SurfaceAuditEntry[];
  lines: string[];
}

const PUBLIC_ROUTE_LABELS: Record<string, string> = {
  "/": "Marketing home",
  "/welcome": "Beta welcome",
  "/beta": "Beta & download",
  "/privacy": "Privacy",
  "/terms": "Terms",
  "/contact": "Contact",
  "/safety": "Safety",
};

const PUBLIC_ROUTES = WEB_PUBLIC_PRODUCTION_ROUTES.map((route) => ({
  route,
  label: PUBLIC_ROUTE_LABELS[route] ?? route,
}));

const INTERNAL_PREFIXES = ["/internal", "/debug"];

export function buildSurfaceAuditReport(): SurfaceAuditReport {
  const generatedAt = new Date().toISOString();
  const entries: SurfaceAuditEntry[] = PUBLIC_ROUTES.map(({ route, label }) => {
    const q = productQuestionForRoute(route);
    return {
      route,
      label,
      tier: q.role,
      productQuestion: q.productQuestion,
      helpsArchiveUnderstanding: q.helpsArchiveUnderstanding,
      utilityOnly: q.utilityOnly,
    };
  });

  for (const prefix of INTERNAL_PREFIXES) {
    entries.push({
      route: `${prefix}/*`,
      label: "Internal / debug",
      tier: "internal",
      productQuestion: null,
      helpsArchiveUnderstanding: false,
      utilityOnly: false,
    });
  }

  const primary = entries.filter((e) => e.tier === "primary");
  const supporting = entries.filter((e) => e.tier === "supporting");
  const utility = entries.filter((e) => e.tier === "utility");
  const internal = entries.filter((e) => e.tier === "internal");
  const directlyImprovesUnderstanding = entries.filter((e) => e.helpsArchiveUnderstanding);

  const lines = [
    `Generated ${generatedAt}`,
    `Primary surfaces: ${primary.length}`,
    `Supporting: ${supporting.length}`,
    `Utility: ${utility.length}`,
    `Internal: ${internal.length}`,
    "",
    'Surfaces that directly improve: "I understand myself better because of this archive."',
    ...directlyImprovesUnderstanding.map(
      (e) => `  • ${e.label} (${e.route}) — ${e.productQuestion}`,
    ),
    "",
    "Utility-only (no archive question):",
    ...utility.map((e) => `  • ${e.label} (${e.route})`),
  ];

  return {
    generatedAt,
    primary,
    supporting,
    utility,
    internal,
    directlyImprovesUnderstanding,
    lines,
  };
}
