import { resolveTheoryMomentum, type TheoryMomentum } from "@/lib/theories/theory-changed";
import type { TheoryEvidenceQuote, TheoryStatus } from "@/types/theory";
import type { JournalEntry } from "@/types/journal";

export const THEORY_RESOLUTION_COPY = {
  softening: "This may be softening",
  mayNoLongerFit: "This theory may no longer fit",
  behaviorChanging:
    "Your recent reflections suggest this pattern may be changing",
} as const;

const RECENT_BEHAVIOR_DAYS = 14;
const MATERIAL_CONFIDENCE_DROP = 7;
const CONTRADICT_INCREASE_THRESHOLD = 2;

export interface TheoryResolutionResult {
  status: TheoryStatus;
  resolutionNote?: string;
}

export interface ResolveTheoryStatusInput {
  confidence: number;
  previousConfidence?: number;
  confidenceDelta: number;
  isFirstSnapshot: boolean;
  createdAt: string;
  supportingCount: number;
  contradictingCount: number;
  baselineContradictingCount?: number;
  contradictingQuotes?: TheoryEvidenceQuote[];
  entriesById?: Map<string, JournalEntry>;
}

function hasRecentBehaviorShift(
  contradictingQuotes: TheoryEvidenceQuote[],
  entriesById: Map<string, JournalEntry>,
): boolean {
  const cutoff = Date.now() - RECENT_BEHAVIOR_DAYS * 24 * 60 * 60 * 1000;
  for (const quote of contradictingQuotes) {
    const entry = entriesById.get(quote.entryId);
    if (!entry) continue;
    if (new Date(entry.createdAt).getTime() >= cutoff) return true;
  }
  return false;
}

function contradictingIncreasedMaterially(
  current: number,
  baseline?: number,
): boolean {
  if (baseline === undefined) {
    return current >= 3;
  }
  return current - baseline >= CONTRADICT_INCREASE_THRESHOLD;
}

function contradictShare(input: {
  supportingCount: number;
  contradictingCount: number;
}): number {
  const total = input.supportingCount + input.contradictingCount;
  if (total === 0) return 0;
  return input.contradictingCount / total;
}

function shouldRetire(input: ResolveTheoryStatusInput): boolean {
  if (input.isFirstSnapshot) return false;

  const share = contradictShare(input);
  if (input.confidence < 30 && input.contradictingCount >= input.supportingCount) {
    return true;
  }
  if (
    input.confidenceDelta <= -12 &&
    input.contradictingCount > 0 &&
    share >= 0.4
  ) {
    return true;
  }
  return input.confidence < 28 && input.contradictingCount >= 2;
}

function shouldResolve(
  input: ResolveTheoryStatusInput,
  recentShift: boolean,
): boolean {
  if (input.isFirstSnapshot) return false;

  const materialDrop =
    input.confidenceDelta <= -MATERIAL_CONFIDENCE_DROP && input.confidence < 52;
  const contradictRising =
    contradictingIncreasedMaterially(
      input.contradictingCount,
      input.baselineContradictingCount,
    ) &&
    input.contradictingCount > 0 &&
    input.confidence < 55;

  if (materialDrop) return true;
  if (contradictRising) return true;
  if (
    recentShift &&
    (input.confidenceDelta <= -3 || input.contradictingCount >= 2)
  ) {
    return true;
  }

  return false;
}

function statusFromMomentum(momentum: TheoryMomentum): TheoryStatus {
  if (momentum === "strengthening") return "strengthening";
  if (momentum === "weakening") return "weakening";
  return "active";
}

/** Final lifecycle status: active, strengthening, weakening, resolved, or retired. */
export function resolveTheoryStatus(
  input: ResolveTheoryStatusInput,
): TheoryResolutionResult {
  const momentum = resolveTheoryMomentum({
    confidence: input.confidence,
    confidenceDelta: input.confidenceDelta,
    isFirstSnapshot: input.isFirstSnapshot,
    createdAt: input.createdAt,
    supportingCount: input.supportingCount,
    contradictingCount: input.contradictingCount,
  });

  if (input.isFirstSnapshot) {
    const status = momentum === "strengthening" ? "strengthening" : "active";
    return { status };
  }

  const recentShift =
    input.contradictingQuotes &&
    input.entriesById &&
    input.contradictingQuotes.length > 0
      ? hasRecentBehaviorShift(input.contradictingQuotes, input.entriesById)
      : false;

  if (shouldRetire(input)) {
    return {
      status: "retired",
      resolutionNote: THEORY_RESOLUTION_COPY.mayNoLongerFit,
    };
  }

  if (shouldResolve(input, recentShift)) {
    return {
      status: "resolved",
      resolutionNote: recentShift
        ? THEORY_RESOLUTION_COPY.behaviorChanging
        : THEORY_RESOLUTION_COPY.mayNoLongerFit,
    };
  }

  if (momentum === "weakening") {
    return {
      status: "weakening",
      resolutionNote: THEORY_RESOLUTION_COPY.softening,
    };
  }

  return { status: statusFromMomentum(momentum) };
}
