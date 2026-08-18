import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { buildRevisitationReport } from "@/lib/memory/revisitation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import {
  findForbiddenTestimonialPhrase,
  readApprovedTestimonials,
  readRejectedTestimonials,
  upsertTestimonialCandidate,
} from "@/lib/social-proof/testimonial-review";
import { findDelayedRevisitGapDays } from "@/lib/social-proof/remembered-later";
import type { JournalEntry } from "@/types/journal";
import type { EmotionalProofSnippet } from "@/types/social-proof";

export const STATIC_QUIET_PROOF_LINES = [
  "Some reflections become clearer later.",
  "People sometimes return to older recordings.",
  "Not everything needs to make sense immediately.",
  "Old reflections are sometimes the ones people return to.",
  "Some reflections make more sense later.",
  "People often replay older recordings.",
] as const;

export const PROOF_FORBIDDEN_PATTERNS = [
  /\b\d+\s*(users?|people|thousands|millions)\b/i,
  /\busers like you\b/i,
  /\bjoin\b/i,
  /\bviral/i,
  /\bstreak/i,
  /\bdon't miss\b/i,
  /\bhurry\b/i,
  /\blimited time\b/i,
  /\bgame changer\b/i,
] as const;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function passesProofRules(text: string): boolean {
  if (!text.trim()) return false;
  for (const pattern of PROOF_FORBIDDEN_PATTERNS) {
    if (pattern.test(text)) return false;
  }
  if (findForbiddenTestimonialPhrase(text)) return false;
  return true;
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function behaviorSnippets(entries: JournalEntry[]): EmotionalProofSnippet[] {
  const sorted = sortedEntries(entries);
  const snippets: EmotionalProofSnippet[] = [];
  const loops = buildRetentionLoopReport();
  const revisitation = buildRevisitationReport(sorted, { context: "memory", limit: 4 });

  const delayedGap = findDelayedRevisitGapDays();
  if (delayedGap !== null) {
    snippets.push({
      id: "behavior-delayed-return",
      text: "Someone came back to this three days later.",
      source: "behavior",
      strength: 72,
      evidence: `Delayed revisit gap ~${delayedGap} days`,
    });
  }

  const replayCount = loops.events.filter(
    (event) => event.kind === "entry_revisited" || event.kind === "old_entry_opened_from_note",
  ).length;
  if (replayCount >= 2) {
    snippets.push({
      id: "behavior-replay-older",
      text: "People often replay older recordings.",
      source: "behavior",
      strength: 68,
      evidence: `${replayCount} revisit events`,
    });
  }

  if (revisitation.hasData && revisitation.notes.length > 0) {
    snippets.push({
      id: "behavior-old-return",
      text: "Old reflections are sometimes the ones people return to.",
      source: "behavior",
      strength: 70,
      evidence: `${revisitation.notes.length} returned threads`,
    });
  }

  if (loops.revisitsCausingReflections.length > 0) {
    snippets.push({
      id: "behavior-clarity-later",
      text: "Some reflections make more sense later.",
      source: "behavior",
      strength: 74,
      evidence: `${loops.revisitsCausingReflections.length} revisit → reflection links`,
    });
  }

  return snippets.filter((row) => passesProofRules(row.text));
}

function approvedTestimonialSnippets(): EmotionalProofSnippet[] {
  return readApprovedTestimonials().map((row) => ({
    id: `testimonial-${row.id}`,
    text: row.text,
    source: "approved_testimonial" as const,
    strength: 76,
    evidence: row.emotionalCategory,
  }));
}

function staticSnippets(): EmotionalProofSnippet[] {
  return STATIC_QUIET_PROOF_LINES.map((text, index) => ({
    id: `static-${index}`,
    text,
    source: "static" as const,
    strength: 58 + (index % 3),
  }));
}

/** Build eligible quiet proof snippets from behavior and approved feedback. */
export function buildEligibleProofSnippets(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): EmotionalProofSnippet[] {
  const merged = [
    ...behaviorSnippets(entries),
    ...approvedTestimonialSnippets(),
    ...staticSnippets(),
  ];

  const seen = new Set<string>();
  const unique: EmotionalProofSnippet[] = [];
  for (const row of merged) {
    const key = row.text.toLowerCase();
    if (seen.has(key) || !passesProofRules(row.text)) continue;
    seen.add(key);
    unique.push(row);
  }

  unique.sort((a, b) => b.strength - a.strength);
  return unique;
}

export function pickQuietProofSnippet(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
  excludeTexts: string[] = [],
): EmotionalProofSnippet | null {
  const exclude = new Set(excludeTexts.map((text) => text.toLowerCase()));
  const candidates = buildEligibleProofSnippets(entries).filter(
    (row) => !exclude.has(row.text.toLowerCase()),
  );
  return candidates[0] ?? null;
}

export function hasMeaningfulArchiveBehavior(entries: JournalEntry[]): boolean {
  const sorted = sortedEntries(entries);
  if (sorted.length < 2) return false;
  const first = toDayKey(sorted[0].createdAt);
  const last = toDayKey(sorted[sorted.length - 1].createdAt);
  return daysBetweenKeys(first, last) >= 2;
}

export function seedTestimonialCandidatesFromCallbacks(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): void {
  if (!isBrowser()) return;
  const report = buildCallbackQualityReviewReport(entries);
  for (const item of report.items.slice(0, 12)) {
    if (item.emotionalResidueScore < 55) continue;
    if (item.text.length > 200) continue;
    if (findForbiddenTestimonialPhrase(item.text)) continue;
    upsertTestimonialCandidate({
      text: item.text,
      emotionalCategory: item.kind === "revisitation" ? "revisit" : "quiet_continuity",
      sourceCallbackIds: [item.id],
      retentionLinkages: item.sourceEntries?.map((e) => e.id) ?? [],
    });
  }
}

export function scanOverclaimedLines(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): Array<{ id: string; text: string; reason: string }> {
  const report = buildCallbackQualityReviewReport(entries);
  const rejected = readRejectedTestimonials();
  const overclaimed: Array<{ id: string; text: string; reason: string }> = [];

  for (const row of rejected) {
    overclaimed.push({
      id: row.id,
      text: row.text,
      reason: row.reason ?? "Rejected testimonial",
    });
  }

  for (const item of report.items) {
    const forbidden = findForbiddenTestimonialPhrase(item.text);
    if (forbidden) {
      overclaimed.push({
        id: item.id,
        text: item.text,
        reason: `Forbidden phrasing: ${forbidden}`,
      });
    }
  }

  return overclaimed.slice(0, 24);
}
