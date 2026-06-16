import fs from "node:fs";
import path from "node:path";

import { buildSurfaceAuditReport } from "@/lib/product/surface-audit";
import {
  countActiveInternalPanels,
  getInternalSurfaceRegistry,
  INTERNAL_COMPLEXITY_ACTIVE_TARGET,
  type InternalSurfaceRecord,
  type StaleDisposition,
} from "@/lib/internal/internal-surface-registry";

export interface InternalComplexityReport {
  generatedAt: string;
  publicRouteCount: number;
  internalRouteCount: number;
  internalToPublicRatio: number;
  activePanelCount: number;
  internalComplexityScore: number;
  meetsActiveTarget: boolean;
  unusedPanels: InternalSurfaceRecord[];
  staleByDisposition: Record<StaleDisposition, InternalSurfaceRecord[]>;
  lines: string[];
}

function listInternalRoutes(appDir: string): string[] {
  const internalRoot = path.join(appDir, "internal");
  if (!fs.existsSync(internalRoot)) return [];

  const routes: string[] = [];
  function walk(dir: string, prefix: string) {
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
      if (!ent.isDirectory()) continue;
      const segment = ent.name.replace(/\[.*\]/g, ":param");
      const route = `${prefix}/${segment}`;
      const page = path.join(dir, ent.name, "page.tsx");
      if (fs.existsSync(page)) routes.push(route);
      walk(path.join(dir, ent.name), route);
    }
  }
  walk(internalRoot, "/internal");
  return routes.sort();
}

function listPublicAppRoutes(appDir: string): string[] {
  const routes: string[] = [];
  function walk(dir: string, prefix: string) {
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
      if (ent.name === "internal" || ent.name === "api" || ent.name.startsWith("_")) continue;
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) {
        const segment = ent.name.startsWith("(") ? "" : `/${ent.name}`;
        walk(full, `${prefix}${segment}`);
        continue;
      }
      if (ent.name === "page.tsx" && prefix) routes.push(prefix || "/");
    }
  }
  walk(appDir, "");
  return [...new Set(routes)].sort();
}

export function buildInternalComplexityReport(
  appDir = path.join(process.cwd(), "app"),
): InternalComplexityReport {
  const generatedAt = new Date().toISOString();
  const registry = getInternalSurfaceRegistry();
  const panels = registry.filter((r) => r.panelComponent);
  const internalRoutes = listInternalRoutes(appDir);
  const publicRoutes = listPublicAppRoutes(appDir);
  const audit = buildSurfaceAuditReport();

  const publicRouteCount = Math.max(
    publicRoutes.length,
    audit.primary.length + audit.supporting.length + audit.utility.length,
  );
  const internalRouteCount = internalRoutes.length;
  const internalToPublicRatio =
    publicRouteCount > 0
      ? Math.round((internalRouteCount / publicRouteCount) * 100) / 100
      : internalRouteCount;

  const activePanelCount = countActiveInternalPanels();
  const internalComplexityScore = activePanelCount;
  const meetsActiveTarget = activePanelCount < INTERNAL_COMPLEXITY_ACTIVE_TARGET;

  const registeredRoutes = new Set(
    panels.map((p) => p.route).filter((r): r is string => Boolean(r)),
  );
  const unusedPanels = panels.filter(
    (p) =>
      p.disposition !== "KEEP" &&
      (!p.hasEvents || !p.hasUsageSignals || !p.drivesDecisions),
  );

  const staleByDisposition: Record<StaleDisposition, InternalSurfaceRecord[]> = {
    KEEP: panels.filter((p) => p.disposition === "KEEP"),
    MERGE: panels.filter((p) => p.disposition === "MERGE"),
    DELETE: panels.filter((p) => p.disposition === "DELETE"),
  };

  const lines = [
    `Generated ${generatedAt}`,
    `Public routes: ${publicRouteCount}`,
    `Internal routes: ${internalRouteCount}`,
    `Internal : public ratio: ${internalToPublicRatio}`,
    `Internal Complexity Score (active KEEP panels): ${internalComplexityScore}`,
    `Target: < ${INTERNAL_COMPLEXITY_ACTIVE_TARGET} active internal panels`,
    meetsActiveTarget ? "Meets active panel target" : "OVER active panel target",
    "",
    "Registered internal routes not in panel registry:",
    ...internalRoutes
      .filter((r) => ![...registeredRoutes].some((reg) => r.startsWith(reg ?? "")))
      .slice(0, 12)
      .map((r) => `  • ${r}`),
    "",
    `Unused / stale candidates: ${unusedPanels.length}`,
    ...unusedPanels.slice(0, 15).map(
      (p) => `  • [${p.disposition}] ${p.label} — ${p.staleReason ?? "review"}`,
    ),
  ];

  return {
    generatedAt,
    publicRouteCount,
    internalRouteCount,
    internalToPublicRatio,
    activePanelCount,
    internalComplexityScore,
    meetsActiveTarget,
    unusedPanels,
    staleByDisposition,
    lines,
  };
}
