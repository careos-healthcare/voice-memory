export type PlanId = "free" | "pro";

export type UpgradeClickSource =
  | "pricing"
  | "memory"
  | "weekly"
  | "search"
  | "export"
  | "journal"
  | "insights"
  | "homepage";

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
    title: "Weekly intelligence",
    description: "Rolling week comparisons, emotional shifts, and AI weekly summaries.",
  },
  {
    id: "entity_memory",
    title: "Entity memory",
    description: "Recurring people, concerns, goals, and topics across your full journal.",
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
  "Last 7 reflections on device",
  "Basic mood & theme reflections",
  "Local-only storage (private by default)",
  "Voice recording & transcript",
  "In-app contextual reminders",
];

export const PRO_PLAN_FEATURES = [
  "Unlimited local reflection history",
  "Full semantic life search",
  "Weekly intelligence & comparisons",
  "Entity memory across all entries",
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
  } catch {
    localStorage.setItem(UPGRADE_CLICKS_KEY, JSON.stringify([event]));
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
