import {
  HEDGE_RE,
  directCount,
  hedgeCount,
  entrySnippet,
  buildLanguageFingerprint,
} from "@/lib/memory/language-fingerprint";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { VoiceTextureMarker, VoiceTextureReport } from "@/types/archive-individuality";

const POLISHED_AI_RE =
  /\b(in conclusion|it's clear that|this reflects|deeply meaningful|profound insight|growth mindset|inner landscape|emotional landscape)\b/i;
const THERAPEUTIC_SUMMARY_RE =
  /\b(processing|working through|healing|journey toward|self-awareness|breakthrough moment)\b/i;
const UNFINISHED_RE = /\b(\.\.\.|—|–|\.\.\.\s*$|\blike\b|\bum\b|\buh\b)\b/i;

function recurringPhrases(entries: JournalEntry[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const entry of entries) {
    const snippet = entrySnippet(entry).toLowerCase();
    const trigrams = snippet.split(/\s+/).slice(0, 12).join(" ");
    if (trigrams.length >= 8) {
      counts.set(trigrams, (counts.get(trigrams) ?? 0) + 1);
    }
  }
  return counts;
}

function detectMarkers(entries: JournalEntry[]): VoiceTextureMarker[] {
  const markers: VoiceTextureMarker[] = [];

  for (const entry of entries) {
    const snippet = entrySnippet(entry);
    const transcript = entry.transcript;

    if (hedgeCount(entry) >= 2) {
      markers.push({
        id: `hesitant-${entry.id}`,
        kind: "hesitant",
        text: snippet.slice(0, 100),
        sourceEntryId: entry.id,
      });
    }

    if (UNFINISHED_RE.test(transcript) || transcript.trim().endsWith("...")) {
      markers.push({
        id: `unfinished-${entry.id}`,
        kind: "unfinished",
        text: snippet.slice(0, 100),
        sourceEntryId: entry.id,
      });
    }

    if (entry.reflection.exactLanguagePattern?.trim()) {
      markers.push({
        id: `personal-${entry.id}`,
        kind: "personal",
        text: entry.reflection.exactLanguagePattern.slice(0, 100),
        sourceEntryId: entry.id,
      });
    }

    if (hedgeCount(entry) >= 1 && directCount(entry) === 0) {
      markers.push({
        id: `imperfect-${entry.id}`,
        kind: "imperfect",
        text: snippet.slice(0, 100),
        sourceEntryId: entry.id,
      });
    }
  }

  const recurring = recurringPhrases(entries);
  for (const [phrase, count] of recurring) {
    if (count >= 2) {
      markers.push({
        id: `recurring-${phrase.slice(0, 20)}`,
        kind: "recurring",
        text: phrase.slice(0, 100),
      });
    }
  }

  const seen = new Set<string>();
  return markers.filter((m) => {
    const key = `${m.kind}:${m.text}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function polishRiskCount(text: string): number {
  let count = 0;
  if (POLISHED_AI_RE.test(text)) count += 1;
  if (THERAPEUTIC_SUMMARY_RE.test(text)) count += 1;
  if (!HEDGE_RE.test(text) && text.length > 120 && /\b(you are|you have become|this shows)\b/i.test(text)) {
    count += 1;
  }
  return count;
}

/** Protect voice texture — unfinished, hesitant, personal wording. */
export function assessVoiceTexture(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): VoiceTextureReport {
  const markers = detectMarkers(entries);
  const fingerprint = buildLanguageFingerprint(entries);

  let polishRisk = 0;
  for (const entry of entries) {
    polishRisk += polishRiskCount(entry.reflection.concreteObservation ?? "");
    polishRisk += polishRiskCount(entry.reflection.exactLanguagePattern ?? "");
  }

  const protectedPhraseCount = markers.filter(
    (m) => m.kind === "personal" || m.kind === "recurring" || m.kind === "hesitant",
  ).length;

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length > 0,
    markers: markers.slice(0, 24),
    protectedPhraseCount,
    polishRiskCount: polishRisk,
    shouldPreserveTexture: Boolean(fingerprint) && protectedPhraseCount >= 2,
  };
}

/** Returns true if cleanup would strip this archive's natural texture. */
export function shouldBlockTextureCleanup(text: string, entries?: JournalEntry[]): boolean {
  const texture = assessVoiceTexture(entries ?? getMemoryEligibleEntries());
  if (!texture.shouldPreserveTexture) return false;
  return polishRiskCount(text) > 0 || (!HEDGE_RE.test(text) && text.length > 100);
}

export function preserveUserWording(candidate: string, sourceEntry: JournalEntry): string {
  const exact = sourceEntry.reflection.exactLanguagePattern?.trim();
  if (exact && exact.length >= 12 && !POLISHED_AI_RE.test(candidate)) {
    return exact.slice(0, 160);
  }
  return candidate;
}
