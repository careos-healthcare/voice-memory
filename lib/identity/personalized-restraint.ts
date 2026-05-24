import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildCallbackDeduplicationReport } from "@/lib/refinement/callback-deduplication";
import {
  buildArchiveIndividualityProfile,
  profileFingerprintSummary,
} from "@/lib/identity/archive-individuality";
import { assessVoiceTexture } from "@/lib/identity/voice-texture";
import { evaluateAntiTemplate } from "@/lib/refinement/anti-template";
import { entrySnippet, DIRECT_RE } from "@/lib/memory/language-fingerprint";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { PersonalizedRestraintResult } from "@/types/archive-individuality";

const HOMOGENIZED_STRUCTURES = [
  /\bsound different\b/i,
  /\bheavier stretch\b/i,
  /\bbefore things settled\b/i,
  /\breturned here\b/i,
  /\byou came back\b/i,
  /\bthis changed later\b/i,
];

function userPhraseOverlap(text: string, entries: JournalEntry[]): number {
  const lower = text.toLowerCase();
  let hits = 0;
  for (const entry of entries) {
    const snippet = entrySnippet(entry).toLowerCase();
    const words = snippet.split(/\s+/).filter((w) => w.length > 4);
    for (const word of words) {
      if (lower.includes(word)) hits += 1;
    }
  }
  return hits;
}

/** Prevent callback homogenization — bias toward this archive's rhythm and wording. */
export function evaluatePersonalizedRestraint(
  callbackText: string,
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): PersonalizedRestraintResult {
  const profile = buildArchiveIndividualityProfile(entries);
  const texture = assessVoiceTexture(entries);
  const antiTemplate = evaluateAntiTemplate(callbackText);
  const reasons: string[] = [];
  const biasToward: string[] = [];

  if (antiTemplate.suppressed) {
    reasons.push(antiTemplate.warning ?? "Template-like callback");
  }

  for (const pattern of HOMOGENIZED_STRUCTURES) {
    if (pattern.test(callbackText)) {
      reasons.push("Product-default emotional structure");
    }
  }

  const overlap = userPhraseOverlap(callbackText, entries);
  if (overlap < 2 && entries.length >= 6) {
    reasons.push("Callback does not echo user's actual wording");
    biasToward.push("user transcript phrasing");
  }

  if (profile.namingStyle.certaintyBand === "hedged" && (callbackText.match(DIRECT_RE)?.length ?? 0) >= 3) {
    reasons.push("Too direct for this archive's hedged naming style");
    biasToward.push("hesitant wording");
  }

  if (profile.silenceRhythm.weakNoteSuppressed && callbackText.length > 140) {
    reasons.push("Too dense during silence suppression window");
    biasToward.push("silence");
  }

  if (profile.pacingStyle.band === "sparse" && /\bcame back sooner\b/i.test(callbackText)) {
    reasons.push("Pacing mismatch — archive is sparse");
    biasToward.push("archive pacing");
  }

  const dedup = buildCallbackDeduplicationReport(entries);
  if (dedup.collapsedTemplates.some((t) => callbackText.toLowerCase().includes(t.split(" (")[0].toLowerCase()))) {
    reasons.push("Repeated emotional structure in this archive");
  }

  if (texture.shouldPreserveTexture) {
    biasToward.push("unfinished phrasing", "personal expressions");
  }

  return {
    allowed: reasons.length === 0,
    reasons,
    biasToward: [...new Set(biasToward)],
  };
}

/** Deprioritize callback ids that fail personalized restraint or homogenize the archive. */
export function deprioritizeHomogenizedCallbackIds(
  candidateIds: string[],
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): Set<string> {
  const report = buildCallbackQualityReviewReport(entries);
  const suppressed = new Set<string>();

  for (const item of report.items) {
    if (!candidateIds.includes(item.id)) continue;
    const result = evaluatePersonalizedRestraint(item.text, entries);
    if (!result.allowed) suppressed.add(item.id);
  }

  return suppressed;
}

export function archiveHomogenizationRisk(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): number {
  const profile = buildArchiveIndividualityProfile(entries);
  const dedup = buildCallbackDeduplicationReport(entries);
  const templatePenalty = dedup.collapsedTemplates.length * 12;
  return Math.max(0, 100 - profile.uniquenessScore + templatePenalty);
}

export function restraintFingerprint(entries: JournalEntry[] = getMemoryEligibleEntries()): string {
  return profileFingerprintSummary(buildArchiveIndividualityProfile(entries));
}
