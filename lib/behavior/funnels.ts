import { LAUNCH_EVENTS, RETENTION_EVENTS, readLocalEvents } from "@/lib/local-analytics";
import { OPEN_LOOP_EVENTS } from "@/lib/open-loops/open-loop-observation";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import { BEHAVIOR_EVENTS } from "@/lib/behavior/observation";
import {
  formatSampleNote,
  qualifyInterpretation,
  ratePercent,
  sampleConfidence,
} from "@/lib/behavior/helpers";
import type { BehaviorFunnelStep } from "@/types/behavior-truth";
import type { LocalAnalyticsEvent } from "@/lib/local-analytics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

function funnelStep(
  id: string,
  label: string,
  numerator: number,
  denominator: number,
  interpretation: string,
): BehaviorFunnelStep {
  const confidence = sampleConfidence(denominator);
  return {
    id,
    label,
    numerator,
    denominator,
    percent: ratePercent(numerator, denominator),
    sampleNote: formatSampleNote(numerator, denominator),
    interpretation: qualifyInterpretation(interpretation, confidence),
    confidence,
  };
}

export function computeBehaviorFunnels(
  events: LocalAnalyticsEvent[],
  entries: JournalEntry[],
): BehaviorFunnelStep[] {
  const sortedEntries = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const reflectionCount = sortedEntries.length;

  const firstReflection =
    events.some((e) => e.name === LAUNCH_EVENTS.firstReflectionCreated) || reflectionCount >= 1;
  const secondReflection =
    events.some((e) => e.name === LAUNCH_EVENTS.secondReflectionCreated) || reflectionCount >= 2;

  const callbackShown = events.filter((e) => e.name === CALLBACK_LEARNING_EVENTS.shown).length;
  const callbackOpened = events.filter((e) => e.name === CALLBACK_LEARNING_EVENTS.opened).length;
  const reflectionAfterCallback = events.filter(
    (e) => e.name === CALLBACK_LEARNING_EVENTS.reflectionAfter,
  ).length;

  const loopPromptShown = new Set(
    events
      .filter((e) => e.name === OPEN_LOOP_EVENTS.promptShown)
      .map((e) => e.meta?.entryId)
      .filter(Boolean),
  ).size;
  const loopCreated = events.filter((e) => e.name === OPEN_LOOP_EVENTS.created).length;

  const loopResurfaced = new Set(
    events
      .filter((e) => e.name === OPEN_LOOP_EVENTS.resurfacingShown)
      .map((e) => e.meta?.openLoopId)
      .filter(Boolean),
  ).size;
  const loopReflectionAfter = events.filter(
    (e) => e.name === OPEN_LOOP_EVENTS.reflectionAfterResurface,
  ).length;

  const pricingViewed = events.filter((e) => e.name === RETENTION_EVENTS.pricingViewed).length;
  const proPreview = events.filter((e) => e.name === BEHAVIOR_EVENTS.proPreviewEnabled).length;

  const firstDenom = firstReflection ? 1 : 0;
  const secondNum = secondReflection ? 1 : 0;

  const steps: BehaviorFunnelStep[] = [
    funnelStep(
      "first_to_second_reflection",
      "First → second reflection",
      secondNum,
      Math.max(firstDenom, reflectionCount >= 1 ? 1 : 0),
      secondReflection
        ? "A second reflection happened — habit may be forming on this device."
        : "Only one reflection so far on this device — return timing is still unknown.",
    ),
    funnelStep(
      "callback_shown_to_opened",
      "Callback shown → opened",
      callbackOpened,
      callbackShown,
      callbackShown === 0
        ? "No callback impressions logged yet."
        : callbackOpened / Math.max(callbackShown, 1) < 0.2
          ? "Most callbacks are seen but not opened — wording or timing may not feel personal enough."
          : "Callbacks are being opened at a meaningful rate when shown.",
    ),
    funnelStep(
      "callback_opened_to_reflection",
      "Callback opened → reflected again",
      reflectionAfterCallback,
      Math.max(callbackOpened, 1),
      reflectionAfterCallback === 0 && callbackOpened > 0
        ? "Opens rarely lead to another reflection yet — the return moment may stop at reading."
        : "Some opens are followed by another reflection on this device.",
    ),
    funnelStep(
      "open_loop_prompt_to_created",
      "Open-loop prompt → loop created",
      loopCreated,
      Math.max(loopPromptShown, 1),
      loopPromptShown === 0
        ? "No open-loop prompts logged yet."
        : loopCreated === 0
          ? "Prompts are showing without loops being kept — the ask may feel heavy or unclear."
          : "Some emotionally unresolved entries are being kept open as threads.",
    ),
    funnelStep(
      "open_loop_resurface_to_reflection",
      "Loop resurfaced → related reflection",
      loopReflectionAfter,
      Math.max(loopResurfaced, 1),
      loopResurfaced === 0
        ? "No open-loop resurfacing logged yet."
        : loopReflectionAfter === 0
          ? "Loops resurface but rarely lead to another reflection on this device."
          : "Open-loop resurfacing sometimes leads to another reflection.",
    ),
    funnelStep(
      "pricing_to_pro_preview",
      "Pricing viewed → Pro preview enabled",
      proPreview,
      Math.max(pricingViewed, 1),
      pricingViewed === 0
        ? "Pricing has not been viewed on this device."
        : proPreview === 0
          ? "Pricing was viewed without enabling Pro preview — price may be ahead of felt value."
          : "Pricing views sometimes lead to Pro preview on this device (local preview only).",
    ),
  ];

  return steps;
}

export function buildBehaviorFunnels(): BehaviorFunnelStep[] {
  if (typeof window === "undefined") return [];
  return computeBehaviorFunnels(readLocalEvents(), getMemoryEligibleEntries());
}
