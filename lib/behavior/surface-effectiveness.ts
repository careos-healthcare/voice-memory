import { readLocalEvents } from "@/lib/local-analytics";
import { OPEN_LOOP_EVENTS } from "@/lib/open-loops/open-loop-observation";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import { FIRST_WEEK_RETENTION_EVENTS } from "@/lib/retention/first-week-observation";
import {
  ATMOSPHERE_CREATED,
  ATMOSPHERE_REVISITED,
} from "@/lib/atmosphere/atmosphere-observation";
import { BEHAVIOR_EVENTS } from "@/lib/behavior/observation";
import { ratePercent } from "@/lib/behavior/helpers";
import type { SurfaceEffectivenessRow } from "@/types/behavior-truth";
import type { LocalAnalyticsEvent } from "@/lib/local-analytics";

interface SurfaceSpec {
  id: string;
  label: string;
  match: (event: LocalAnalyticsEvent) => boolean;
  isOpen: (event: LocalAnalyticsEvent) => boolean;
  isReflection: (event: LocalAnalyticsEvent) => boolean;
}

const SURFACE_SPECS: SurfaceSpec[] = [
  {
    id: "homepage_callback",
    label: "Homepage callback",
    match: (e) =>
      e.name === CALLBACK_LEARNING_EVENTS.shown && (e.meta?.surface ?? "") === "homepage",
    isOpen: (e) =>
      (e.name === CALLBACK_LEARNING_EVENTS.opened ||
        e.name === CALLBACK_LEARNING_EVENTS.reread) &&
      (e.meta?.surface ?? "") === "homepage",
    isReflection: (e) =>
      e.name === CALLBACK_LEARNING_EVENTS.reflectionAfter &&
      (e.meta?.surface ?? "") === "homepage",
  },
  {
    id: "entry_callback",
    label: "Entry callback",
    match: (e) =>
      e.name === CALLBACK_LEARNING_EVENTS.shown && (e.meta?.surface ?? "") === "entry",
    isOpen: (e) =>
      (e.name === CALLBACK_LEARNING_EVENTS.opened ||
        e.name === CALLBACK_LEARNING_EVENTS.reread) &&
      (e.meta?.surface ?? "") === "entry",
    isReflection: (e) =>
      e.name === CALLBACK_LEARNING_EVENTS.reflectionAfter &&
      (e.meta?.surface ?? "") === "entry",
  },
  {
    id: "open_loop_resurfacing",
    label: "Open-loop resurfacing",
    match: (e) => e.name === OPEN_LOOP_EVENTS.resurfacingShown,
    isOpen: (e) => e.name === OPEN_LOOP_EVENTS.entryReopened,
    isReflection: (e) => e.name === OPEN_LOOP_EVENTS.reflectionAfterResurface,
  },
  {
    id: "return_prompt",
    label: "Return prompt",
    match: (e) => e.name === FIRST_WEEK_RETENTION_EVENTS.returnPromptOpened,
    isOpen: (e) => e.name === FIRST_WEEK_RETENTION_EVENTS.returnPromptOpened,
    isReflection: (e) => e.name === FIRST_WEEK_RETENTION_EVENTS.reflectionAfterPrompt,
  },
  {
    id: "atmosphere",
    label: "Atmosphere picker",
    match: (e) => e.name === ATMOSPHERE_CREATED || e.name === ATMOSPHERE_REVISITED,
    isOpen: (e) => e.name === ATMOSPHERE_REVISITED,
    isReflection: () => false,
  },
  {
    id: "install_prompt",
    label: "Install prompt",
    match: (e) => e.name === BEHAVIOR_EVENTS.installPromptShown,
    isOpen: (e) => e.name === BEHAVIOR_EVENTS.installAccepted,
    isReflection: () => false,
  },
];

function verdictFor(
  seen: number,
  openRate: number,
  reflectionRate: number,
): SurfaceEffectivenessRow["verdict"] {
  if (seen < 2) return "insufficient";
  if (reflectionRate >= 25 || openRate >= 35) return "strong";
  if (openRate < 10 && reflectionRate < 5) return "ignored";
  return "mixed";
}

function plainFor(row: Omit<SurfaceEffectivenessRow, "plain">): string {
  if (row.verdict === "insufficient") {
    return `${row.label} — not enough impressions on this device yet.`;
  }
  if (row.verdict === "ignored") {
    return `${row.label} is often seen but rarely opened or followed by another reflection.`;
  }
  if (row.verdict === "strong") {
    return `${row.label} correlates with opens or follow-up reflections on this device.`;
  }
  return `${row.label} gets some attention but not consistently tied to another reflection.`;
}

export function computeSurfaceEffectiveness(
  events: LocalAnalyticsEvent[],
): SurfaceEffectivenessRow[] {
  return SURFACE_SPECS.map((spec) => {
    const seen = events.filter(spec.match).length;
    const opened = events.filter(spec.isOpen).length;
    const reflectedAfter = events.filter(spec.isReflection).length;
    const openRate = ratePercent(opened, seen);
    const reflectionRate = ratePercent(reflectedAfter, seen);
    const verdict = verdictFor(seen, openRate, reflectionRate);
    const base = {
      id: spec.id,
      label: spec.label,
      seen,
      opened,
      reflectedAfter,
      openRate,
      reflectionRate,
      verdict,
    };
    return { ...base, plain: plainFor(base) };
  });
}

export function pickStrongestSurfaces(rows: SurfaceEffectivenessRow[]): SurfaceEffectivenessRow[] {
  return [...rows]
    .filter((row) => row.verdict === "strong")
    .sort((a, b) => b.reflectionRate - a.reflectionRate || b.openRate - a.openRate)
    .slice(0, 3);
}

export function pickIgnoredSurfaces(rows: SurfaceEffectivenessRow[]): SurfaceEffectivenessRow[] {
  return rows.filter((row) => row.verdict === "ignored");
}
