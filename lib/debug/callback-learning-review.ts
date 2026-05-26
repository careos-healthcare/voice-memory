import {
  assessCallbackLearning,
  collectCallbackLearningCandidates,
  readCallbackLearningEvents,
  readCallbackLearningWeights,
  CALLBACK_LEARNING_EVENTS,
} from "@/lib/revisit/callback-learning";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  CallbackLearningDebugReport,
  CallbackLearningEventName,
  CallbackLearningKind,
  CallbackLearningReviewRow,
} from "@/types/callback-learning";

function sortWeights(weights: Record<CallbackLearningKind, number>, direction: "desc" | "asc") {
  return (Object.entries(weights) as Array<[CallbackLearningKind, number]>)
    .map(([kind, weight]) => ({ kind, weight }))
    .sort((a, b) => (direction === "desc" ? b.weight - a.weight : a.weight - b.weight));
}

export function buildCallbackLearningDebugReport(): CallbackLearningDebugReport {
  const entries = getMemoryEligibleEntries();
  const candidates = collectCallbackLearningCandidates(entries);
  const weights = readCallbackLearningWeights();
  const events = readCallbackLearningEvents(80);

  const eventCounts = Object.values(CALLBACK_LEARNING_EVENTS).reduce(
    (acc, name) => {
      acc[name] = events.filter((row) => row.event === name).length;
      return acc;
    },
    {} as Record<CallbackLearningEventName, number>,
  );

  const sampleAdjustments: CallbackLearningReviewRow[] = candidates
    .slice(0, 12)
    .map((note) => {
      const verdict = assessCallbackLearning(note, entries);
      return {
        noteId: note.id,
        text: note.text,
        kinds: verdict.kinds,
        rankAdjustment: verdict.rankAdjustment,
        interactionBoost: verdict.interactionBoost,
      };
    })
    .sort((a, b) => Math.abs(b.rankAdjustment) - Math.abs(a.rankAdjustment));

  return {
    generatedAt: new Date().toISOString(),
    hasData: events.length > 0 || candidates.length > 0,
    weights,
    eventCounts,
    totalEvents: events.length,
    topBoostedKinds: sortWeights(weights, "desc").filter((row) => row.weight > 0).slice(0, 6),
    topReducedKinds: sortWeights(weights, "asc").filter((row) => row.weight < 0).slice(0, 6),
    recentEvents: events.slice(0, 20),
    sampleAdjustments,
  };
}
