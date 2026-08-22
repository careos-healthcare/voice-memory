import { buildArchiveIndividualityProfile, profileFingerprintSummary } from "@/lib/identity/archive-individuality";
import { buildLongitudinalIndividualityReport } from "@/lib/identity/longitudinal-individuality";
import { archiveHomogenizationRisk } from "@/lib/identity/personalized-restraint";
import { buildCallbackDeduplicationReport } from "@/lib/refinement/callback-deduplication";
import { scanAntiTemplateViolations } from "@/lib/refinement/anti-template";
import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { readStudyParticipantRoster } from "@/lib/research/retention-observation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveDivergenceReviewReport, ArchiveDivergenceRow } from "@/types/archive-individuality";

const COHORT_KEY = "voicememory_individuality_cohort_snapshots";
const MAX_SNAPSHOTS = 12;

const PRODUCT_DEFAULT_FAMILIES: Array<{ id: string; label: string; pattern: RegExp }> = [
  { id: "sound-different", label: "You sound different", pattern: /\bsound different\b/i },
  { id: "heavier-stretch", label: "Heavier stretch", pattern: /\bheavier stretch\b/i },
  { id: "before-settled", label: "Before things settled", pattern: /\bbefore things\b/i },
  { id: "returned-here", label: "Returned here", pattern: /\breturned here\b/i },
  { id: "changed-later", label: "Changed later", pattern: /\bchanged later\b/i },
  { id: "settled-down", label: "Settled down", pattern: /\bsettled down\b/i },
];

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

interface CohortSnapshot {
  participantId: string;
  label?: string;
  fingerprint: string;
  uniquenessScore: number;
  capturedAt: string;
}

function readCohortSnapshots(): CohortSnapshot[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(COHORT_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as CohortSnapshot[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeCohortSnapshot(snapshot: CohortSnapshot): void {
  if (!isBrowser()) return;
  const existing = readCohortSnapshots().filter((s) => s.participantId !== snapshot.participantId);
  const next = [...existing, snapshot].slice(-MAX_SNAPSHOTS);
  localStorage.setItem(COHORT_KEY, JSON.stringify(next));
}

function captureCurrentSnapshot(): void {
  if (!isBrowser()) return;
  const entries = getMemoryEligibleEntries();
  const profile = buildArchiveIndividualityProfile(entries);
  const participantId =
    typeof localStorage !== "undefined"
      ? localStorage.getItem("voicememory_study_participant_id") ?? "local"
      : "local";

  writeCohortSnapshot({
    participantId,
    label: readStudyParticipantRoster().find((r) => r.id === participantId)?.label,
    fingerprint: profileFingerprintSummary(profile),
    uniquenessScore: profile.uniquenessScore,
    capturedAt: new Date().toISOString(),
  });
}

function row(
  id: string,
  label: string,
  detail: string,
  category: ArchiveDivergenceRow["category"],
  severity: ArchiveDivergenceRow["severity"] = "watch",
): ArchiveDivergenceRow {
  return { id, label, detail, category, severity };
}

function divergenceSuggestions(
  profile: ReturnType<typeof buildArchiveIndividualityProfile>,
): string[] {
  const suggestions: string[] = [];
  if (profile.namingStyle.certaintyBand === "hedged") {
    suggestions.push("Prefer their hesitant phrasing over polished clarity");
  }
  if (profile.pacingStyle.band === "sparse") {
    suggestions.push("Widen resurfacing to match sparse pacing");
  }
  if (profile.emotionalVocabulary.themeCount >= 2) {
    suggestions.push("Ground callbacks in their recurring themes, not product defaults");
  }
  if (profile.silenceRhythm.weakNoteSuppressed) {
    suggestions.push("Honor silence rhythm — fewer notes");
  }
  suggestions.push("Quote their transcript wording when possible");
  return [...new Set(suggestions)].slice(0, 5);
}

/** Founder archive divergence review — homogenization across archives. */
export function buildArchiveDivergenceReviewReport(): ArchiveDivergenceReviewReport {
  captureCurrentSnapshot();

  const entries = getMemoryEligibleEntries();
  const profile = buildArchiveIndividualityProfile(entries);
  const longitudinal = buildLongitudinalIndividualityReport(entries);
  const dedup = buildCallbackDeduplicationReport(entries);
  const callbacks = buildCallbackQualityReviewReport(entries);
  const cohort = readCohortSnapshots();
  const homogenization = archiveHomogenizationRisk(entries);

  const rows: ArchiveDivergenceRow[] = [];

  for (const family of PRODUCT_DEFAULT_FAMILIES) {
    const matches = callbacks.items.filter((i) => family.pattern.test(i.text));
    if (matches.length >= 2) {
      rows.push(
        row(
          `family-${family.id}`,
          `Overused callback family: ${family.label}`,
          `${matches.length} callbacks using product-default structure`,
          "overused_family",
          matches.length >= 4 ? "concern" : "watch",
        ),
      );
    }
  }

  for (const pattern of dedup.patterns.filter((p) => p.count >= 3)) {
    rows.push(
      row(
        `spread-${pattern.id}`,
        "Emotional structure spreading widely",
        `${pattern.label} repeated ${pattern.count}× in this archive`,
        "spreading_structure",
        "concern",
      ),
    );
  }

  const antiTemplate = scanAntiTemplateViolations(
    callbacks.items.map((i) => ({ id: i.id, text: i.text })),
  );
  for (const violation of antiTemplate.slice(0, 4)) {
    rows.push(
      row(
        `default-${violation.id}`,
        "Phrase collapsing into default",
        violation.reasons.join("; "),
        "default_phrase",
        "watch",
      ),
    );
  }

  if (cohort.length >= 2) {
    const fingerprints = new Map<string, number>();
    for (const snap of cohort) {
      fingerprints.set(snap.fingerprint, (fingerprints.get(snap.fingerprint) ?? 0) + 1);
    }
    for (const [fp, count] of fingerprints) {
      if (count >= 2) {
        rows.push(
          row(
            `similar-${fp.slice(0, 16)}`,
            "Archives becoming emotionally similar",
            `${count} stored snapshots share the same individuality fingerprint`,
            "similar_archives",
            "concern",
          ),
        );
      }
    }

    const avgUniqueness =
      cohort.reduce((s, c) => s + c.uniquenessScore, 0) / cohort.length;
    if (avgUniqueness < 40) {
      rows.push(
        row(
          "cohort-low-uniqueness",
          "Cohort uniqueness low",
          `Average uniqueness ${Math.round(avgUniqueness)} across ${cohort.length} snapshots`,
          "similar_archives",
          "concern",
        ),
      );
    }
  }

  const specificityLoss =
    profile.emotionalVocabulary.diversityScore < 35 ||
    callbacks.items.filter((i) => i.manualLabels.includes("felt_generic")).length >= 4;

  const archivesConverging = homogenization >= 50 || longitudinal.converging;

  const founderWarnings: string[] = [];
  if (specificityLoss) {
    founderWarnings.push("The product may be losing emotional specificity.");
  }
  if (archivesConverging || rows.some((r) => r.category === "similar_archives")) {
    founderWarnings.push("Different users may be starting to sound the same.");
  }

  return {
    generatedAt: new Date().toISOString(),
    hasData: entries.length > 0 || rows.length > 0,
    rows,
    divergenceQuestion: "What would make this archive feel more uniquely theirs?",
    homogenizationScore: homogenization,
    archivesConverging,
    specificityLoss,
    founderWarnings,
    suggestions: divergenceSuggestions(profile),
  };
}
