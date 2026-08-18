import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { getMemoryEligibleEntries } from "@/lib/storage";
import { buildRememberedLaterReport } from "@/lib/social-proof/remembered-later";
import { findForbiddenTestimonialPhrase } from "@/lib/social-proof/testimonial-review";
import type { RevisitExperiencePresentation } from "@/lib/refinement/revisit-experience";
import type { LongTermIntention } from "@/types/long-term-intentions";
import type { ReflectiveRoundupLine } from "@/types/reflective-roundup";
import type { QuietShareCard, QuietShareSource } from "@/types/sharing";

export const STATIC_QUIET_SHARE_LINES = [
  "You sound different now.",
  "You kept coming back to this.",
  "This meant something different later.",
  "You had not named this yet.",
] as const;

export const SHARING_FORBIDDEN_PHRASES = [
  "healing journey",
  "become your best self",
  "best version of myself",
  "main character",
  "romanticize your life",
  "growth journey",
  "level up",
  "crush your goals",
  "manifest",
  "you got this",
  "hustle",
  "grind",
  "self-improvement",
  "inspirational",
  "motivational",
  "go viral",
  "share your growth",
  "productivity boost",
  "life-changing",
  "transformed me",
] as const;

export const SHARING_PREFERRED_SIGNALS = [
  "sound different",
  "came back",
  "returned",
  "named",
  "later",
  "before",
  "now",
  "quieter",
  "remembered",
  "meant something",
] as const;

function trimLine(text: string, max = 160): string {
  const trimmed = text.trim().replace(/\s+/g, " ");
  if (trimmed.length <= max) return trimmed;
  return `${trimmed.slice(0, max - 1)}…`;
}

export function findSharingCringeRisk(text: string): string | null {
  const lower = text.toLowerCase();
  for (const phrase of SHARING_FORBIDDEN_PHRASES) {
    if (lower.includes(phrase)) return phrase;
  }
  if (findForbiddenTestimonialPhrase(text)) return "testimonial overclaim";
  if (/\b(streak|kpi|goal crush|mindset shift)\b/i.test(text)) return "productivity tone";
  if (/\b(you deserve|believe in yourself|shine bright)\b/i.test(text)) return "inspirational framing";
  return null;
}

export function passesSharingRestraint(text: string): boolean {
  if (!text.trim()) return false;
  if (findSharingCringeRisk(text)) return false;
  if (/\b\d+\s*(days?|hours?|percent|%)\b/i.test(text)) return false;
  return true;
}

function groundedScore(text: string): number {
  let score = 40;
  const lower = text.toLowerCase();
  for (const signal of SHARING_PREFERRED_SIGNALS) {
    if (lower.includes(signal)) score += 8;
  }
  if (findSharingCringeRisk(text)) score -= 50;
  if (text.length > 140) score -= 6;
  return Math.max(0, Math.min(100, score));
}

export function buildQuietShareCard(input: {
  line: string;
  source: QuietShareSource;
  id?: string;
  beforeLabel?: string;
  nowLabel?: string;
  sourceId?: string;
  entryId?: string;
  callbackId?: string;
}): QuietShareCard | null {
  const line = trimLine(input.line);
  if (!passesSharingRestraint(line)) return null;

  return {
    id: input.id ?? `share-${crypto.randomUUID()}`,
    line,
    beforeLabel: input.beforeLabel,
    nowLabel: input.nowLabel,
    source: input.source,
    sourceId: input.sourceId,
    entryId: input.entryId,
    callbackId: input.callbackId,
  };
}

export function buildRevisitQuietShareCard(
  experience: RevisitExperiencePresentation,
  entryId: string,
): QuietShareCard | null {
  if (!experience.isRevisit) return null;

  if (experience.thenVsNow?.text) {
    return buildQuietShareCard({
      id: `share-revisit-${entryId}`,
      line: experience.thenVsNow.text,
      beforeLabel: experience.thenVsNow.pastDateLabel ?? "Before",
      nowLabel: experience.thenVsNow.currentDateLabel ?? "Now",
      source: "before_now",
      sourceId: experience.thenVsNow.id,
      entryId,
      callbackId: experience.thenVsNow.id,
    });
  }

  if (experience.revisitReward?.text) {
    return buildQuietShareCard({
      id: `share-revisit-reward-${entryId}`,
      line: experience.revisitReward.text,
      source: "revisit_payoff",
      sourceId: experience.revisitReward.id,
      entryId,
      callbackId: experience.revisitReward.id,
    });
  }

  return buildQuietShareCard({
    id: `share-revisit-generic-${entryId}`,
    line: STATIC_QUIET_SHARE_LINES[1],
    source: "revisit_payoff",
    entryId,
  });
}

export function buildRoundupQuietShareCard(line: ReflectiveRoundupLine): QuietShareCard | null {
  return buildQuietShareCard({
    id: `share-roundup-${line.id}`,
    line: line.text,
    source: "roundup",
    sourceId: line.id,
    entryId: line.entryIds[0],
  });
}

export function buildIntentionQuietShareCard(intention: LongTermIntention): QuietShareCard | null {
  return buildQuietShareCard({
    id: `share-intention-${intention.id}`,
    line: intention.text,
    source: "intention",
    sourceId: intention.id,
    entryId: intention.sourceEntryIds[intention.sourceEntryIds.length - 1],
  });
}

export function buildCopiedMomentQuietShareCard(input: {
  text: string;
  sourceId: string;
  entryId?: string;
  noteId?: string;
}): QuietShareCard | null {
  return buildQuietShareCard({
    id: `share-copied-${input.sourceId}`,
    line: input.text,
    source: "copied_moment",
    sourceId: input.sourceId,
    entryId: input.entryId,
    callbackId: input.noteId,
  });
}

export function buildRememberedLaterShareCandidates(): QuietShareCard[] {
  const remembered = buildRememberedLaterReport();
  return remembered.rows
    .filter((row) => row.remembered72h || row.score >= 40)
    .slice(0, 8)
    .map((row) =>
      buildQuietShareCard({
        id: `share-remembered-${row.callbackId}`,
        line: row.text,
        source: "remembered_later",
        sourceId: row.callbackId,
        callbackId: row.callbackId,
      }),
    )
    .filter((card): card is QuietShareCard => card !== null);
}

export function buildEligibleQuietShareCards(
  entries = getMemoryEligibleEntries(),
): QuietShareCard[] {
  const callbackReport = buildCallbackQualityReviewReport(entries);
  const cards: QuietShareCard[] = [];

  for (const item of callbackReport.items.slice(0, 16)) {
    if (item.emotionalResidueScore < 45) continue;
    const card = buildQuietShareCard({
      id: `share-callback-${item.id}`,
      line: item.text,
      source: "remembered_later",
      sourceId: item.id,
      callbackId: item.id,
    });
    if (card) cards.push(card);
  }

  for (const line of STATIC_QUIET_SHARE_LINES) {
    const card = buildQuietShareCard({ line, source: "revisit_payoff" });
    if (card) cards.push(card);
  }

  return cards.sort((a, b) => groundedScore(b.line) - groundedScore(a.line));
}

export function scoreShareableLine(text: string): number {
  return groundedScore(text);
}

export function scanCringeRiskLines(
  lines: Array<{ id: string; text: string }>,
): Array<{ id: string; text: string; reason: string }> {
  return lines
    .map((row) => {
      const reason = findSharingCringeRisk(row.text);
      return reason ? { ...row, reason } : null;
    })
    .filter((row): row is { id: string; text: string; reason: string } => row !== null);
}
