import "server-only";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import type { PatternMatchConfidenceBand } from "@/types/insights";

import { retrieveEvidenceScored } from "@/src/services/ledger/retrieve";

import type { CuriosityEvidenceGateResult } from "./types";

// Exported so the curiosity-loop suite can pin them. Everything downstream of
// this gate — whether a notification is allowed to fire at all — is decided by
// these four numbers, and `evaluateCuriosityEvidenceGate` needs Postgres, so
// they are otherwise unreachable from a static validator.
export const STRONG_MAX_DISTANCE = 0.22;
export const SOLID_MAX_DISTANCE = 0.34;
export const MIN_MATCHES_FOR_STRONG = 3;
export const MIN_MATCHES_FOR_SOLID = 2;

const CONTRADICTION_PAIRS: readonly [RegExp, RegExp][] = [
 [/\b(yes|ready|want to|going to|will)\b/i, /\b(no|not ready|don't want|won't|can't)\b/i],
 [/\b(happy|calm|relief|lighter|hopeful)\b/i, /\b(anxious|stressed|worried|overwhelmed|heavy)\b/i],
 [/\b(trust|confident|sure)\b/i, /\b(doubt|unsure|uncertain|second-guess)\b/i],
];

function assertPostgresAvailable(): void {
  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required for curiosity evidence checks.");
  }
}

export function inferConfidenceBand(
  matches: readonly { distance: number }[],
): PatternMatchConfidenceBand {
  if (matches.length === 0) return "weak";

  const closeMatches = matches.filter((match) => match.distance <= SOLID_MAX_DISTANCE);
  const topDistance = matches[0]?.distance ?? 1;

  if (
    closeMatches.length >= MIN_MATCHES_FOR_STRONG &&
    topDistance <= STRONG_MAX_DISTANCE
  ) {
    return "strong";
  }
  if (
    closeMatches.length >= MIN_MATCHES_FOR_SOLID ||
    topDistance <= STRONG_MAX_DISTANCE
  ) {
    return "solid";
  }
  if (closeMatches.length >= 1 || topDistance <= 0.45) return "emerging";
  return "weak";
}

function extractThemeLabel(matches: readonly { rawText: string }[]): string | null {
  const words = matches
    .flatMap((match) => match.rawText.toLowerCase().split(/[^a-z0-9']+/))
    .filter((word) => word.length >= 4);
  const counts = new Map<string, number>();
  for (const word of words) {
    counts.set(word, (counts.get(word) ?? 0) + 1);
  }
  const ranked = [...counts.entries()]
    .filter(([, count]) => count >= 2)
    .sort((left, right) => right[1] - left[1]);
  return ranked[0]?.[0] ?? null;
}

function excerptFromText(rawText: string, maxChars = 96): string {
  const collapsed = rawText.replace(/\s+/g, " ").trim();
  if (collapsed.length <= maxChars) return collapsed;
  return `${collapsed.slice(0, maxChars - 1).trim()}…`;
}

function detectContradiction(
  matches: readonly { entryId: string; rawText: string }[],
): { entryIds: [string, string] } | null {
  if (matches.length < 2) return null;

  for (let leftIndex = 0; leftIndex < Math.min(matches.length, 4); leftIndex += 1) {
    for (let rightIndex = leftIndex + 1; rightIndex < Math.min(matches.length, 4); rightIndex += 1) {
      const left = matches[leftIndex];
      const right = matches[rightIndex];
      for (const [positive, negative] of CONTRADICTION_PAIRS) {
        const leftPos = positive.test(left.rawText);
        const rightNeg = negative.test(right.rawText);
        const leftNeg = negative.test(left.rawText);
        const rightPos = positive.test(right.rawText);
        if ((leftPos && rightNeg) || (leftNeg && rightPos)) {
          const sorted = [left.entryId, right.entryId].sort();
          return { entryIds: [sorted[0], sorted[1]] };
        }
      }
    }
  }
  return null;
}

function patternSurfaceKey(entryIds: readonly string[]): string {
  return `pattern:${[...entryIds].sort().join("|")}`;
}

function contradictionSurfaceKey(entryIds: readonly [string, string]): string {
  return `contradiction:${entryIds[0]}|${entryIds[1]}`;
}

async function hasSurfaced(userId: string, surfaceKey: string): Promise<boolean> {
  assertPostgresAvailable();
  const result = await dbQuery<{ exists: boolean }>(
    `SELECT EXISTS(
       SELECT 1 FROM curiosity_notification_surfaces
       WHERE user_id = $1 AND surface_key = $2
     ) AS exists`,
    [userId, surfaceKey],
  );
  return result.rows[0]?.exists === true;
}

export async function recordCuriositySurface(input: {
  userId: string;
  surfaceKey: string;
  kind: "pattern" | "contradiction";
  citedEntryIds: string[];
}): Promise<void> {
  assertPostgresAvailable();
  await dbQuery(
    `INSERT INTO curiosity_notification_surfaces (user_id, surface_key, kind, cited_entry_ids)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, surface_key) DO NOTHING`,
    [input.userId, input.surfaceKey, input.kind, input.citedEntryIds],
  );
}

/**
 * Evidence gate — notifications may fire only on solid/strong patterns or unsurfaced contradictions.
 */
export async function evaluateCuriosityEvidenceGate(
  userId: string,
  queryText: string,
): Promise<CuriosityEvidenceGateResult> {
  const normalizedUserId = userId.trim();
  const normalizedQuery = queryText.trim();
  if (!normalizedUserId || !normalizedQuery) {
    return {
      eligible: false,
      reason: "insufficient_evidence",
      confidenceBand: "weak",
      citedEntryIds: [],
      themeLabel: null,
      excerpt: null,
      contradictionEntryIds: null,
      surfaceKey: null,
    };
  }

  const matches = await retrieveEvidenceScored(normalizedUserId, normalizedQuery, 8);
  if (matches.length === 0) {
    return {
      eligible: false,
      reason: "insufficient_evidence",
      confidenceBand: "weak",
      citedEntryIds: [],
      themeLabel: null,
      excerpt: null,
      contradictionEntryIds: null,
      surfaceKey: null,
    };
  }

  const confidenceBand = inferConfidenceBand(matches);
  const citedEntryIds = matches.slice(0, 4).map((match) => match.entryId);
  const themeLabel = extractThemeLabel(matches);
  const excerpt = excerptFromText(matches[0].rawText);

  const contradiction = detectContradiction(matches);
  if (contradiction) {
    const surfaceKey = contradictionSurfaceKey(contradiction.entryIds);
    if (await hasSurfaced(normalizedUserId, surfaceKey)) {
      return {
        eligible: false,
        reason: "already_surfaced",
        confidenceBand,
        citedEntryIds,
        themeLabel,
        excerpt,
        contradictionEntryIds: [...contradiction.entryIds],
        surfaceKey,
      };
    }
    return {
      eligible: true,
      reason: "unsurfaced_contradiction",
      confidenceBand,
      citedEntryIds: [...contradiction.entryIds],
      themeLabel,
      excerpt,
      contradictionEntryIds: [...contradiction.entryIds],
      surfaceKey,
    };
  }

  if (confidenceBand !== "solid" && confidenceBand !== "strong") {
    return {
      eligible: false,
      reason: "weak_match",
      confidenceBand,
      citedEntryIds,
      themeLabel,
      excerpt,
      contradictionEntryIds: null,
      surfaceKey: null,
    };
  }

  const surfaceKey = patternSurfaceKey(citedEntryIds);
  if (await hasSurfaced(normalizedUserId, surfaceKey)) {
    return {
      eligible: false,
      reason: "already_surfaced",
      confidenceBand,
      citedEntryIds,
      themeLabel,
      excerpt,
      contradictionEntryIds: null,
      surfaceKey,
    };
  }

  return {
    eligible: true,
    reason: confidenceBand === "strong" ? "strong_pattern" : "solid_pattern",
    confidenceBand,
    citedEntryIds,
    themeLabel,
    excerpt,
    contradictionEntryIds: null,
    surfaceKey,
  };
}
