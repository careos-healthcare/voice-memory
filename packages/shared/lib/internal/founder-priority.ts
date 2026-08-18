import fs from "node:fs";
import path from "node:path";

import { INTERNAL_PANEL_REGISTRY } from "@/lib/internal/internal-surface-registry";
import type {
  FounderDecisionScore,
  FounderPriorityTier,
  NorthStarMetricId,
} from "@/types/founder-focus";

export type FounderPanelPriorityRecord = {
  id: string;
  label: string;
  route?: string;
  panelComponent?: string;
  tier: FounderPriorityTier;
  northStarMetric?: NorthStarMetricId;
  changesProductDecision: FounderDecisionScore;
  archiveReason: string;
};

export const NORTH_STAR_METRIC_IDS: readonly NorthStarMetricId[] = [
  "activation",
  "return",
  "curiosity",
  "attachment",
  "conversion",
] as const;

export const FOUNDER_DASHBOARD_TAB_IDS = [
  "activation",
  "return",
  "conversion",
] as const;

/** Routes founders see in primary navigation. */
export const FOUNDER_PRIMARY_ROUTES = [
  "/internal",
  "/internal/launch",
] as const;

const CORE_METRIC_PANELS: FounderPanelPriorityRecord[] = NORTH_STAR_METRIC_IDS.map(
  (metric) => ({
    id: `north-star-${metric}`,
    label: `North star — ${metric}`,
    route: "/internal/activation",
    tier: "CORE",
    northStarMetric: metric,
    changesProductDecision: "YES",
    archiveReason: "One of five company-health metrics",
  }),
);

const FOUNDER_DASHBOARD_PANELS: FounderPanelPriorityRecord[] =
  FOUNDER_DASHBOARD_TAB_IDS.map((tab) => ({
    id: `founder-dashboard-tab-${tab}`,
    label: `Founder dashboard tab — ${tab}`,
    route: "/internal",
    tier: "CORE",
    changesProductDecision: "YES",
    archiveReason: "Founder dashboard tab (max 3)",
  }));

function tierForRegistryPanel(
  drivesDecisions: boolean,
): { tier: FounderPriorityTier; decision: FounderDecisionScore } {
  if (drivesDecisions) {
    return { tier: "ARCHIVED", decision: "NO" };
  }
  return { tier: "ARCHIVED", decision: "NO" };
}

function mapRegistryPanels(): FounderPanelPriorityRecord[] {
  return INTERNAL_PANEL_REGISTRY.map((panel) => {
    const { tier, decision } = tierForRegistryPanel(panel.drivesDecisions);
    return {
      id: panel.id,
      label: panel.label,
      route: panel.route,
      panelComponent: panel.panelComponent,
      tier,
      changesProductDecision: decision,
      archiveReason:
        decision === "NO"
          ? "Would not change a product decision under v2 focus"
          : panel.staleReason ?? "Legacy internal panel",
    };
  });
}

function listInternalRoutes(appDir = path.join(process.cwd(), "app")): string[] {
  const internalRoot = path.join(appDir, "internal");
  if (!fs.existsSync(internalRoot)) return [];

  const routes: string[] = [];
  function walk(dir: string, prefix: string) {
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
      if (!ent.isDirectory()) continue;
      const route = `${prefix}/${ent.name}`;
      const page = path.join(dir, ent.name, "page.tsx");
      if (fs.existsSync(page)) routes.push(route);
      walk(path.join(dir, ent.name), route);
    }
  }
  walk(internalRoot, "/internal");
  return routes.sort();
}

function routePanels(): FounderPanelPriorityRecord[] {
  const registeredRoutes = new Set(
    INTERNAL_PANEL_REGISTRY.map((p) => p.route).filter(Boolean),
  );

  return listInternalRoutes()
    .filter((route) => !registeredRoutes.has(route))
    .filter((route) => !FOUNDER_PRIMARY_ROUTES.includes(route as (typeof FOUNDER_PRIMARY_ROUTES)[number]))
    .map((route) => ({
      id: `route-${route.replace(/\//g, "-").replace(/^-/, "")}`,
      label: route,
      route,
      tier: "ARCHIVED" as const,
      changesProductDecision: "NO" as const,
      archiveReason: "Secondary internal route — link removed from founder nav",
    }));
}

/** Full classification registry for validate:founder-focus. */
export function getFounderPanelPriorityRegistry(): FounderPanelPriorityRecord[] {
  return [
    ...CORE_METRIC_PANELS,
    ...FOUNDER_DASHBOARD_PANELS,
    ...mapRegistryPanels(),
    ...routePanels(),
  ];
}

export function getCoreNorthStarPanels(): FounderPanelPriorityRecord[] {
  return getFounderPanelPriorityRegistry().filter((p) => p.tier === "CORE");
}

export function getArchivedPanels(): FounderPanelPriorityRecord[] {
  return getFounderPanelPriorityRegistry().filter((p) => p.tier === "ARCHIVED");
}

export function findUnclassifiedPanelIds(ids: string[]): string[] {
  const known = new Set(getFounderPanelPriorityRegistry().map((p) => p.id));
  return ids.filter((id) => !known.has(id));
}
