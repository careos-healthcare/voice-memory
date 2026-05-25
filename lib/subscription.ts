import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";

export type PlanId = "free" | "pro";

export type UpgradeClickSource =
  | "pricing"
  | "memory"
  | "weekly"
  | "search"
  | "export"
  | "journal"
  | "insights"
  | "homepage"
  | "pilot";

export interface UpgradeClickEvent {
  source: UpgradeClickSource;
  clickedAt: string;
  feature?: string;
}

export const FREE_ENTRY_LIMIT = 7;
export const PRO_PRICE_LABEL = "£8.99/month";

const PLAN_KEY = "voicememory_plan";
const UPGRADE_CLICKS_KEY = "voicememory_upgrade_clicks";

export interface ProMemoryFeature {
  id: string;
  title: string;
  description: string;
  comingSoon?: boolean;
}

export const PRO_MEMORY_FEATURES: ProMemoryFeature[] = [
  {
    id: "full_history",
    title: "Full memory history",
    description: "Every reflection, not just your last 7 entries.",
  },
  {
    id: "semantic_search",
    title: "Semantic life search",
    description: "Search your whole story in plain language across all fields.",
  },
  {
    id: "weekly_intelligence",
    title: "Weekly resurfacing",
    description: "Rolling week comparisons and words that came back in your own voice.",
  },
  {
    id: "entity_memory",
    title: "Entity memory",
    description:
      "Recurring people, concerns, goals, and topics across your full memory history.",
  },
  {
    id: "export_reports",
    title: "Export reports",
    description: "JSON archives, weekly text exports, and printable reflection reports.",
  },
  {
    id: "encrypted_sync",
    title: "Future encrypted sync",
    description: "End-to-end encrypted backup across devices — coming after billing launches.",
    comingSoon: true,
  },
];

export const FREE_PLAN_FEATURES = [
  "Last 7 voice reflections on device",
  "Resurfacing from recent reflections",
  "Local-first memory (private by default)",
  "Voice capture & transcript",
  "In-app contextual reminders",
];

export const PRO_PLAN_FEATURES = [
  "Full private memory history",
  "Full semantic memory search",
  "Weekly resurfacing from your voice",
  "Entity memory across all reflections",
  "Export JSON, weekly summaries & print reports",
  "Priority access to encrypted sync (coming soon)",
];

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function getPlanId(): PlanId {
  if (!isBrowser()) return "free";
  return localStorage.getItem(PLAN_KEY) === "pro" ? "pro" : "free";
}

export function isProUser(): boolean {
  return getPlanId() === "pro";
}

/** Local-only preview toggle for development (no Stripe). */
export function setPlanId(plan: PlanId): void {
  if (!isBrowser()) return;
  localStorage.setItem(PLAN_KEY, plan);
}

export function trackUpgradeClick(
  source: UpgradeClickSource,
  feature?: string,
): void {
  if (!isBrowser()) return;

  const event: UpgradeClickEvent = {
    source,
    clickedAt: new Date().toISOString(),
    feature,
  };

  try {
    const raw = localStorage.getItem(UPGRADE_CLICKS_KEY);
    const existing = raw ? (JSON.parse(raw) as UpgradeClickEvent[]) : [];
    existing.push(event);
    localStorage.setItem(
      UPGRADE_CLICKS_KEY,
      JSON.stringify(existing.slice(-100)),
    );
    trackLaunchEvent(LAUNCH_EVENTS.upgradeClicked, { source, feature: feature ?? "" });
  } catch {
    localStorage.setItem(UPGRADE_CLICKS_KEY, JSON.stringify([event]));
    trackLaunchEvent(LAUNCH_EVENTS.upgradeClicked, { source, feature: feature ?? "" });
  }
}

export function getUpgradeClickEvents(): UpgradeClickEvent[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(UPGRADE_CLICKS_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as UpgradeClickEvent[];
  } catch {
    return [];
  }
}

export function requiresProForExportReports(): boolean {
  return !isProUser();
}

/** Reset local Pro preview toggle (development / settings). */
export function clearProPreview(): void {
  if (!isBrowser()) return;
  localStorage.setItem(PLAN_KEY, "free");
}
