import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { hasLocalEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import {
  trackFlowDropOff,
  trackFlowStepCompleted,
} from "@/lib/onboarding/onboarding-observation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { FirstSessionFlowStep, FirstSessionFlowStepId } from "@/types/onboarding-clarity";

const FLOW_KEY = "voicememory_first_session_flow";
const SESSION_START_KEY = "voicememory_first_session_started_at";

const STEP_ORDER: FirstSessionFlowStepId[] = [
  "first_reflection",
  "quiet_revisit",
  "continuity_moment",
  "archive_perception",
];

const STEP_LABELS: Record<FirstSessionFlowStepId, string> = {
  first_reflection: "First recording saved",
  quiet_revisit: "Opened an older note calmly",
  continuity_moment: "Saw a line connect across days",
  archive_perception: "Understood notes stay on this device",
};

interface PersistedFlow {
  startedAt: string;
  steps: Partial<Record<FirstSessionFlowStepId, { completedAt?: string; droppedAt?: string }>>;
  replayCount: number;
  silencePreferred: boolean;
  confusionFlags: number;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readFlow(): PersistedFlow {
  if (!isBrowser()) {
    return {
      startedAt: new Date().toISOString(),
      steps: {},
      replayCount: 0,
      silencePreferred: false,
      confusionFlags: 0,
    };
  }
  try {
    const raw = localStorage.getItem(FLOW_KEY);
    if (!raw) return ensureSessionStarted(defaultFlow());
    return { ...defaultFlow(), ...(JSON.parse(raw) as PersistedFlow) };
  } catch {
    return ensureSessionStarted(defaultFlow());
  }
}

function defaultFlow(): PersistedFlow {
  return {
    startedAt: new Date().toISOString(),
    steps: {},
    replayCount: 0,
    silencePreferred: false,
    confusionFlags: 0,
  };
}

function ensureSessionStarted(flow: PersistedFlow): PersistedFlow {
  if (!isBrowser()) return flow;
  const existing = localStorage.getItem(SESSION_START_KEY);
  if (!existing) {
    localStorage.setItem(SESSION_START_KEY, flow.startedAt);
  }
  return { ...flow, startedAt: existing ?? flow.startedAt };
}

function writeFlow(flow: PersistedFlow): void {
  if (!isBrowser()) return;
  localStorage.setItem(FLOW_KEY, JSON.stringify(flow));
}

export function markFirstSessionStarted(): void {
  const flow = ensureSessionStarted(readFlow());
  writeFlow(flow);
}

export function completeFirstSessionStep(stepId: FirstSessionFlowStepId): void {
  const flow = readFlow();
  if (flow.steps[stepId]?.completedAt) return;
  flow.steps[stepId] = { completedAt: new Date().toISOString() };
  writeFlow(flow);
  trackFlowStepCompleted(stepId);
}

export function dropFirstSessionStep(stepId: FirstSessionFlowStepId, reason: string): void {
  const flow = readFlow();
  if (flow.steps[stepId]?.completedAt) return;
  flow.steps[stepId] = {
    ...flow.steps[stepId],
    droppedAt: new Date().toISOString(),
  };
  writeFlow(flow);
  trackFlowDropOff(stepId, reason);
}

export function recordSessionReplay(): void {
  const flow = readFlow();
  flow.replayCount += 1;
  writeFlow(flow);
}

export function recordSilencePreference(): void {
  const flow = readFlow();
  flow.silencePreferred = true;
  writeFlow(flow);
}

export function recordFlowConfusionFlag(): void {
  const flow = readFlow();
  flow.confusionFlags += 1;
  writeFlow(flow);
}

export function getFirstSessionElapsedMs(): number {
  const flow = readFlow();
  return Date.now() - new Date(flow.startedAt).getTime();
}

export function isWithinFirstTwoMinutes(): boolean {
  return getFirstSessionElapsedMs() <= 2 * 60 * 1000;
}

export function buildFirstSessionFlowSteps(): FirstSessionFlowStep[] {
  const flow = readFlow();
  return STEP_ORDER.map((id) => ({
    id,
    label: STEP_LABELS[id],
    completedAt: flow.steps[id]?.completedAt ?? null,
    droppedAt: flow.steps[id]?.droppedAt ?? null,
  }));
}

export function firstSessionCompletionRate(): number {
  const steps = buildFirstSessionFlowSteps();
  const done = steps.filter((s) => s.completedAt).length;
  return steps.length === 0 ? 0 : done / steps.length;
}

export function inferFlowProgressFromAppState(): void {
  const entries = getMemoryEligibleEntries();
  if (entries.length >= 1 || hasLocalEvent(LAUNCH_EVENTS.firstReflectionCreated)) {
    completeFirstSessionStep("first_reflection");
  }
  if (hasLocalEvent("revisit_opened") || hasLocalEvent("first_session_old_reflection_opened")) {
    completeFirstSessionStep("quiet_revisit");
  }
  if (hasLocalEvent("revisit_reward_seen") || hasLocalEvent("first_callback_landed")) {
    completeFirstSessionStep("continuity_moment");
  }
  if (hasLocalEvent("onboarding_completed") || hasLocalEvent("export_used")) {
    completeFirstSessionStep("archive_perception");
  }
}

export function firstSessionDropOffPoints(): string[] {
  const steps = buildFirstSessionFlowSteps();
  const points: string[] = [];
  for (let i = 0; i < steps.length; i += 1) {
    const step = steps[i];
    if (step.droppedAt && !step.completedAt) {
      points.push(`Dropped at ${step.label}`);
    }
    if (!step.completedAt && !step.droppedAt) {
      const priorDone = steps.slice(0, i).every((s) => s.completedAt);
      if (priorDone && i > 0) {
        points.push(`Stalled before ${step.label}`);
      }
    }
  }
  if (!isWithinFirstTwoMinutes() && firstSessionCompletionRate() < 0.5) {
    points.push("Left before two-minute clarity window ended");
  }
  return points;
}

export function hoursSinceFirstSession(): number | null {
  const flow = readFlow();
  if (!flow.startedAt) return null;
  return (Date.now() - new Date(flow.startedAt).getTime()) / (1000 * 60 * 60);
}

export function isInFirstAhaWindow(): boolean {
  const hours = hoursSinceFirstSession();
  if (hours === null) return false;
  return hours >= 24 && hours <= 72;
}
