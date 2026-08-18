import type {
  RoundupLineCandidate,
  RoundupQualityReason,
  RoundupQualityVerdict,
} from "@/types/roundup-quality-review";
import { applyObservationScoreAdjustments } from "@/lib/roundups/roundup-observation";
import type { ReflectiveRoundupLine, ReflectiveRoundupSignal } from "@/types/reflective-roundup";

export const ROUNDUP_MAX_LINES = 5;

const GENERIC_FALLBACK_RE = /^Your voice kept circling the same ground\.?$/i;

const GENERIC_THEME_RE =
  /^(?:you kept returning to|returning to)\s+(?:work|life|stress|things|stuff|everything|it all|this|that)\.?$/i;

const SUMMARY_LIKE_RE =
  /\b(?:in summary|to summarize|overall|looking back|recap|highlights|key takeaways|wrapped up|takeaways from)\b/i;

const PERIOD_SUMMARY_RE =
  /\bthis (?:week|month|period|time) (?:was|has been|shows|felt like|looked like)\b/i;

const READS_DIFFERENTLY_RE =
  /^This (?:month|period|week) reads differently from the beginning\.?$/i;

const PRODUCTIVITY_LIKE_RE =
  /\b(?:action plan|goal dashboard|productivity score|habit completion|smart goal|coaching plan|to[\s-]?do list|task list|deadline|deliverable|milestone completion|productivity|kpi|okr|streak count|checklist|time block)\b/i;

const OVERCLAIM_CHANGE_RE =
  /\b(?:completely changed|totally different|transformed|dramatically|profound shift|deeply shifted|major shift|everything changed|fundamentally different|clearly improved|definitely changed)\b/i;

const UNIVERSAL_TEMPLATE_RES: RegExp[] = [
  GENERIC_FALLBACK_RE,
  READS_DIFFERENTLY_RE,
  /^The (?:week|month|period) felt (?:heavier|lighter) toward the end\.?$/i,
];

export interface RoundupQualityContext {
  pickedTexts?: string[];
  pickedThemes?: Set<string>;
}

function normalizeLine(text: string): string {
  return text.trim().replace(/\s+/g, " ").toLowerCase();
}

export function extractReturningTheme(text: string): string | null {
  const match = text.match(/^You kept returning to (.+)\.?$/i);
  return match?.[1]?.trim().toLowerCase() ?? null;
}

function noteTheme(text: string, themes: Set<string>): void {
  const theme = extractReturningTheme(text);
  if (theme) themes.add(theme);
}

/** Assess whether a roundup line should stay quiet. */
export function assessRoundupLineQuality(
  line: RoundupLineCandidate,
  context: RoundupQualityContext = {},
): RoundupQualityVerdict {
  const reasons: RoundupQualityReason[] = [];
  const text = line.text.trim();

  if (!line.entryIds || line.entryIds.length === 0) {
    reasons.push("lacks_source_entries");
  }

  if (GENERIC_FALLBACK_RE.test(text) || GENERIC_THEME_RE.test(normalizeLine(text))) {
    reasons.push("generic");
  }

  if (SUMMARY_LIKE_RE.test(text) || PERIOD_SUMMARY_RE.test(text) || READS_DIFFERENTLY_RE.test(text)) {
    reasons.push("sounds_like_summary");
  }

  if (PRODUCTIVITY_LIKE_RE.test(text)) {
    reasons.push("productivity_like");
  }

  if (OVERCLAIM_CHANGE_RE.test(text)) {
    reasons.push("overclaims_change");
  }

  if (UNIVERSAL_TEMPLATE_RES.some((re) => re.test(text))) {
    reasons.push("could_apply_to_anyone");
  }

  const theme = extractReturningTheme(text);
  if (theme && context.pickedThemes?.has(theme)) {
    reasons.push("repeat_theme_without_change");
  }

  const normalized = normalizeLine(text);
  if (context.pickedTexts?.some((picked) => normalizeLine(picked) === normalized)) {
    reasons.push("repeat_theme_without_change");
  }

  return {
    suppressed: reasons.length > 0,
    reasons,
  };
}

/** Pick roundup lines with quality guardrails — prefer quiet over generic copy. */
export function pickQualityRoundupLines(
  candidates: RoundupLineCandidate[],
): ReflectiveRoundupLine[] {
  const tuned = applyObservationScoreAdjustments(candidates);
  const usedSignals = new Set<ReflectiveRoundupSignal>();
  const pickedTexts: string[] = [];
  const pickedThemes = new Set<string>();
  const sorted = [...tuned].sort((a, b) => b.score - a.score);
  const picked: ReflectiveRoundupLine[] = [];

  for (const candidate of sorted) {
    if (picked.length >= ROUNDUP_MAX_LINES) break;
    if (usedSignals.has(candidate.signal)) continue;

    const verdict = assessRoundupLineQuality(candidate, { pickedTexts, pickedThemes });
    if (verdict.suppressed) continue;

    usedSignals.add(candidate.signal);
    pickedTexts.push(candidate.text);
    noteTheme(candidate.text, pickedThemes);
    picked.push({
      id: `roundup-${candidate.signal}-${picked.length}`,
      text: candidate.text,
      entryIds: candidate.entryIds,
      signal: candidate.signal,
      score: candidate.score,
    });
  }

  return picked;
}

export interface EvaluatedRoundupCandidate {
  candidate: RoundupLineCandidate;
  qualitySuppressed: boolean;
  qualityReasons: RoundupQualityReason[];
  selected: boolean;
}

/** Simulate selection order for debug review — mirrors production guardrails. */
export function evaluateRoundupCandidates(
  candidates: RoundupLineCandidate[],
): EvaluatedRoundupCandidate[] {
  const tuned = applyObservationScoreAdjustments(candidates);
  const usedSignals = new Set<ReflectiveRoundupSignal>();
  const pickedTexts: string[] = [];
  const pickedThemes = new Set<string>();
  const sorted = [...tuned].sort((a, b) => b.score - a.score);
  const results: EvaluatedRoundupCandidate[] = [];
  let selectedCount = 0;

  for (const candidate of sorted) {
    const duplicateSignal = usedSignals.has(candidate.signal);
    const atCapacity = selectedCount >= ROUNDUP_MAX_LINES;
    const verdict = assessRoundupLineQuality(candidate, { pickedTexts, pickedThemes });
    const selected =
      !atCapacity && !duplicateSignal && !verdict.suppressed;

    if (selected) {
      selectedCount += 1;
      usedSignals.add(candidate.signal);
      pickedTexts.push(candidate.text);
      noteTheme(candidate.text, pickedThemes);
    }

    results.push({
      candidate,
      qualitySuppressed: verdict.suppressed,
      qualityReasons: verdict.reasons,
      selected,
    });
  }

  return results;
}
