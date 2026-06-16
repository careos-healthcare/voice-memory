import { applyDeleteCandidateRules } from "@/lib/internal/delete-candidate-detector";
import type {
  InternalArchiveRecord,
  InternalArchiveStatus,
} from "@/types/internal-archive";

export const INTERNAL_COMMAND_CENTER_ROUTE = "/internal";

export const INTERNAL_LAUNCH_ROUTE = "/internal/launch";

export const LAUNCH_DECISION = {
  decisionQuestion: "Can we launch mobile and growth loops together?",
  decisionAction:
    "Ship only when activation, return, revenue, distribution, and store evidence are green.",
};

export const INTERNAL_COMMAND_PILLARS: readonly {
  id: InternalArchiveRecord["pillar"];
  route: string;
  label: string;
  decisionQuestion: string;
  decisionAction: string;
}[] = [
  {
    id: "activation",
    route: "/internal/activation",
    label: "Activation",
    decisionQuestion: "Are people reaching a first working belief?",
    decisionAction:
      "If activation is below target, narrow onboarding and defer paywall until belief forms.",
  },
  {
    id: "return",
    route: "/internal/return",
    label: "Return",
    decisionQuestion: "Are people coming back after the archive changes?",
    decisionAction:
      "If return is weak, strengthen archive-change prompts and return triggers before new features.",
  },
  {
    id: "conversion",
    route: "/internal/conversion",
    label: "Conversion",
    decisionQuestion: "Are people paying after archive value is felt?",
    decisionAction:
      "If conversion lags, adjust paywall timing and proof on archive — not homepage feature sprawl.",
  },
  {
    id: "distribution",
    route: "/internal/distribution",
    label: "Distribution",
    decisionQuestion: "Are people sharing and referring without paid ads?",
    decisionAction:
      "If sharing is flat, ship more transformation moments and share cards — not a community layer.",
  },
  {
    id: "mobile",
    route: "/internal/mobile-readiness",
    label: "Mobile Readiness",
    decisionQuestion: "Is the Flutter app store-ready with evidence?",
    decisionAction:
      "If not ready, finish evidence files and parity gaps before marketing mobile.",
  },
] as const;

const MERGE_TARGETS: Record<string, string> = {
  "/internal/archive-attachment": "/internal/return",
  "/internal/archive-moat": "/internal/return",
  "/internal/return-trigger-attribution": "/internal/return",
  "/internal/organic-referral": "/internal/return",
  "/internal/paywall-attribution": "/internal/conversion",
  "/internal/retention-discovery": "/internal/return",
  "/internal/archive": "/internal",
  "/internal/north-star": "/internal/activation",
  "/internal/entitlements": "/internal/conversion",
};

/** All internal app routes (static inventory). */
export const INTERNAL_ROUTE_INVENTORY: readonly string[] = [
  "/internal",
  "/internal/activation",
  "/internal/return",
  "/internal/conversion",
  "/internal/distribution",
  "/internal/mobile-readiness",
  "/internal/launch",
  "/internal/apple-store-readiness",
  "/internal/google-play-readiness",
  "/internal/store-readiness",
  "/internal/mobile-parity",
  "/internal/mobile-web-parity",
  "/internal/mobile-archive-review",
  "/internal/mobile-push-readiness",
  "/internal/retention-discovery",
  "/internal/retention-core",
  "/internal/founder-test",
  "/internal/founder-review",
  "/internal/product-simplification",
  "/internal/archive-belief",
  "/internal/archive-reputation",
  "/internal/archive-attachment",
  "/internal/archive-moat",
  "/internal/paywall-attribution",
  "/internal/return-trigger-attribution",
  "/internal/organic-referral",
  "/internal/emotional-integrity",
  "/internal/onboarding-clarity",
  "/internal/performance-health",
  "/internal/theory-discovery",
  "/internal/theory-curiosity",
  "/internal/blind-spot-discovery",
  "/internal/blind-spot-performance",
  "/internal/archive-voice",
  "/internal/auth-value-validation",
  "/internal/archive-divergence",
  "/internal/archive-individuality",
  "/internal/archive-simplicity",
  "/internal/sacredness-review",
  "/internal/durability-review",
  "/internal/callback-learning",
  "/internal/behavior-truth",
  "/internal/reflection-friction",
  "/internal/resurfacing-variety",
  "/internal/resurfacing-timing",
  "/internal/resurfacing-confidence",
  "/internal/silence-intelligence",
  "/internal/first-magic-moment",
  "/internal/first-week-retention",
  "/internal/recurrence-density",
  "/internal/transcript-cleanup",
  "/internal/vulnerability-timing",
  "/internal/open-loop-activation",
  "/internal/open-loop-performance",
  "/internal/open-loops-readout",
  "/internal/entitlements",
  "/internal/push-verification",
  "/internal/north-star",
  "/internal/archive",
] as const;

const ROUTE_LABELS: Record<string, string> = {
  "/internal": "Command center",
  "/internal/activation": "Activation hub",
  "/internal/return": "Return hub",
  "/internal/conversion": "Conversion hub",
  "/internal/distribution": "Distribution hub",
  "/internal/mobile-readiness": "Mobile readiness",
  "/internal/launch": "Launch readiness",
};

function routeToId(route: string): string {
  return route.replace(/^\/internal\/?/, "").replace(/\//g, "-") || "command-center";
}

function buildBaseRecord(route: string): InternalArchiveRecord {
  const pillar = INTERNAL_COMMAND_PILLARS.find((p) => p.route === route);
  const isCommandCenter = route === INTERNAL_COMMAND_CENTER_ROUTE;
  const isLaunch = route === INTERNAL_LAUNCH_ROUTE;
  const isPillar = Boolean(pillar);
  const active = isCommandCenter || isLaunch || isPillar;

  return {
    id: routeToId(route),
    route,
    label:
      ROUTE_LABELS[route] ??
      (route.replace("/internal/", "").replace(/-/g, " ") || "Internal"),
    status: active ? "ACTIVE" : "ARCHIVED",
    discoverable: active,
    pillar: pillar?.id,
    mergedInto: MERGE_TARGETS[route],
    hasEvents: isPillar || isLaunch,
    hasUsageSignals: isPillar || isLaunch,
    drivesDecisions: active,
    decisionQuestion: isCommandCenter
      ? "Where should I spend the next hour as founder?"
      : isLaunch
        ? LAUNCH_DECISION.decisionQuestion
        : pillar?.decisionQuestion,
    decisionAction: isCommandCenter
      ? "Open one pillar hub, make one decision, then stop."
      : isLaunch
        ? LAUNCH_DECISION.decisionAction
        : pillar?.decisionAction,
    staleReason: active ? undefined : "Consolidated into command center pillars",
  };
}

const REGISTRY: InternalArchiveRecord[] = applyDeleteCandidateRules(
  [...new Set(INTERNAL_ROUTE_INVENTORY)].map(buildBaseRecord),
);

export function getInternalArchiveRegistry(): InternalArchiveRecord[] {
  return REGISTRY;
}

export function getActiveInternalArchiveRecords(): InternalArchiveRecord[] {
  return REGISTRY.filter((r) => r.status === "ACTIVE");
}

export function getDiscoverableInternalRoutes(): InternalArchiveRecord[] {
  return REGISTRY.filter((r) => r.discoverable);
}

export function countActiveInternalDashboards(): number {
  return getActiveInternalArchiveRecords().filter(
    (r) => r.route !== INTERNAL_COMMAND_CENTER_ROUTE,
  ).length;
}

export function countArchivedInternalDashboards(): number {
  return REGISTRY.filter((r) => r.status === "ARCHIVED").length;
}

export function getInternalArchiveByRoute(route: string): InternalArchiveRecord | undefined {
  return REGISTRY.find((r) => r.route === route);
}

export function assertActivePanelHasDecision(record: InternalArchiveRecord): boolean {
  if (record.status !== "ACTIVE") return true;
  return Boolean(record.decisionQuestion?.trim() && record.decisionAction?.trim());
}

export const INTERNAL_SURFACE_REDUCTION_TARGET = 0.7;

export function internalSurfaceReductionRatio(): number {
  const all = REGISTRY;
  if (all.length === 0) return 0;
  const archived = all.filter(
    (r) => r.status === "ARCHIVED" || r.status === "DELETE_CANDIDATE",
  ).length;
  return archived / all.length;
}

export function toLegacyDisposition(
  status: InternalArchiveStatus,
): "KEEP" | "MERGE" | "DELETE" {
  if (status === "ACTIVE") return "KEEP";
  if (status === "DELETE_CANDIDATE") return "DELETE";
  return "MERGE";
}
