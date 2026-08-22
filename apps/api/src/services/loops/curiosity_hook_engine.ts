import "server-only";

import type { CuriosityHook, CuriosityHookEntryMetadata, CuriosityHookType } from "./types";

const MAX_ANCHOR_CHARS = 72;
const MAX_RECENT_TYPES = 4;

const MOMENTUM_TONE_SIGNALS = [
  "lighter",
  "lighter than",
  "hopeful",
  "calm",
  "relief",
  "clearer",
  "easier",
  "steady",
  "settled",
];

/**
 * Selects hook targeting metadata only — no notification copy lives here.
 * Message text is built separately from `fact_ledger` evidence.
 */
export function buildCuriosityHook(input: {
  metadata: CuriosityHookEntryMetadata;
  recentHookTypes?: readonly CuriosityHookType[];
  now?: Date;
}): CuriosityHook | null {
  const entryId = input.metadata.entryId.trim();
  if (!entryId) return null;

  const anchor = primaryAnchor(input.metadata.extractedAnchors);
  if (!anchor) return null;

  const hookType = selectHookType(
    input.metadata,
    input.recentHookTypes ?? [],
  );
  if (!hookType) return null;

  const createdAt = input.metadata.createdAt.trim();
  if (!createdAt || !Number.isFinite(Date.parse(createdAt))) return null;

  const clock = input.now ?? new Date();
  return {
    id: hookId(entryId, clock),
    entryId,
    createdAt: new Date(createdAt).toISOString(),
    primaryAnchor: anchor,
    hookType,
    sourceEntryId: entryId,
  };
}

function primaryAnchor(extractedAnchors: readonly string[]): string | null {
  for (const raw of extractedAnchors) {
    const trimmed = raw.trim();
    if (!trimmed) continue;
    if (trimmed.length <= MAX_ANCHOR_CHARS) return trimmed;
    return `${trimmed.slice(0, MAX_ANCHOR_CHARS - 1).trim()}…`;
  }
  return null;
}

function selectHookType(
  metadata: CuriosityHookEntryMetadata,
  recentHookTypes: readonly CuriosityHookType[],
): CuriosityHookType | null {
  const recent = recentHookTypes.slice(0, MAX_RECENT_TYPES);
  const candidates: CuriosityHookType[] = [];

  if (metadata.hasBlockers) candidates.push("blocker");
  if (hasMomentumTone(metadata.emotionalTone) && !metadata.hasBlockers) {
    candidates.push("momentum");
  }
  if ((metadata.entryCount ?? 0) >= 3) candidates.push("returnWatch");
  candidates.push("anchorFollowUp");

  for (const candidate of candidates) {
    if (!recentlyUsed(candidate, recent)) return candidate;
  }

  for (const candidate of candidates) {
    if (recent.length === 0 || recent[0] !== candidate) return candidate;
  }

  return candidates[0] ?? null;
}

function recentlyUsed(
  candidate: CuriosityHookType,
  recent: readonly CuriosityHookType[],
): boolean {
  if (recent.length === 0) return false;
  if (recent[0] === candidate) return true;
  if (recent.length >= 2 && recent[1] === candidate) return true;
  return false;
}

function hasMomentumTone(emotionalTone: string | undefined): boolean {
  const tone = emotionalTone?.trim().toLowerCase();
  if (!tone) return false;
  return MOMENTUM_TONE_SIGNALS.some((signal) => tone.includes(signal));
}

function hookId(entryId: string, createdAt: Date): string {
  return `curiosity_${entryId}_${createdAt.getTime()}`;
}
