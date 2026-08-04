import { buildArchiveAccuracyView } from "@/lib/archive/archive-accuracy";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import {
  buildArchiveImplications,
  implicationsAnswerLines,
} from "@/lib/archive/archive-implications";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import { buildBeliefSurvivalView } from "@/lib/archive/belief-survival";
import { buildContradictionHistoryView } from "@/lib/archive/contradiction-history";
import {
  ARCHIVE_QUESTION_PROMPTS,
  ARCHIVE_TRUST_BAND_LABEL,
} from "@/lib/archive/archive-question-copy";
import {
  emotionalConfidenceLine,
  emotionalWeakenedLine,
} from "@/lib/archive/archive-emotional-copy";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { clampConfidence } from "@/lib/theories/theory-confidence-movement";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveQuestionAnswer,
  ArchiveQuestionAnswerKey,
  ArchiveQuestionAnswers,
  ArchiveQuestionId,
} from "@/types/archive-question";
import type { ArchiveReputationLevel } from "@/types/archive-reputation";
import type { JournalEntry } from "@/types/journal";
import type { TheoryEvidenceQuote } from "@/types/theory";

const QUOTE_MAX = 96;

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function truncateQuote(text: string): string {
  const t = text.replace(/\s+/g, " ").trim();
  if (t.length <= QUOTE_MAX) return t;
  return `${t.slice(0, QUOTE_MAX - 1)}…`;
}

function formatLifeAreas(areas: string[]): string | null {
  const labels = areas.slice(0, 4).map((a) => a.toLowerCase());
  if (labels.length === 0) return null;
  if (labels.length === 1) return labels[0]!;
  if (labels.length === 2) return `${labels[0]} and ${labels[1]}`;
  return `${labels.slice(0, -1).join(", ")}, and ${labels[labels.length - 1]}`;
}

function trustBand(level: ArchiveReputationLevel): keyof typeof ARCHIVE_TRUST_BAND_LABEL {
  if (level === "low") return "low";
  if (level === "developing") return "developing";
  return "strong";
}

function trustExplanation(level: ArchiveReputationLevel, summary: string): string {
  const band = ARCHIVE_TRUST_BAND_LABEL[trustBand(level)];
  return `${band} — ${summary}`;
}

function quoteLines(quotes: TheoryEvidenceQuote[]): string[] {
  return quotes
    .map((q) => truncateQuote(q.quote))
    .filter((line) => line.length > 0)
    .slice(0, 6);
}

function pickStrongestQuote(quotes: TheoryEvidenceQuote[]): string | null {
  if (quotes.length === 0) return null;
  const sorted = [...quotes].sort((a, b) => b.quote.length - a.quote.length);
  return truncateQuote(sorted[0]!.quote);
}

function buildAnswer(
  questionId: ArchiveQuestionId,
  answerKey: ArchiveQuestionAnswerKey,
  answerLines: string[],
  evidenceLines: string[] = [],
): ArchiveQuestionAnswer {
  return {
    questionId,
    questionLabel: ARCHIVE_QUESTION_PROMPTS[questionId],
    answerLines: answerLines.filter(Boolean),
    evidenceLines: evidenceLines.filter(Boolean),
  };
}

type QuestionContext = {
  belief: NonNullable<ReturnType<typeof buildArchiveBeliefView>>;
  survival: ReturnType<typeof buildBeliefSurvivalView>;
  reputation: ReturnType<typeof buildArchiveReputationView>;
  accuracy: ReturnType<typeof buildArchiveAccuracyView>;
  contradiction: ReturnType<typeof buildContradictionHistoryView>;
  leadTheory: ReturnType<typeof buildTheoryTrackerReport>["all"][number] | null;
};

function buildContext(entries: JournalEntry[]): QuestionContext | null {
  const belief = buildArchiveBeliefView(entries);
  if (!belief) return null;

  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const lead =
    report.all.find((t) => t.id === belief.theoryId) ?? report.all[0] ?? null;

  return {
    belief,
    survival: buildBeliefSurvivalView(entries, { theoryId: belief.theoryId }),
    reputation: buildArchiveReputationView(entries),
    accuracy: buildArchiveAccuracyView(entries),
    contradiction: buildContradictionHistoryView(entries, { theoryId: belief.theoryId }),
    leadTheory: lead ?? null,
  };
}

function buildWhyAnswer(ctx: QuestionContext): ArchiveQuestionAnswer {
  const lines: string[] = [];
  const rep = ctx.reputation;
  const surv = ctx.survival;
  const lead = ctx.leadTheory;

  if (rep) {
    lines.push(
      `${rep.supportingReflections} saved moment${rep.supportingReflections === 1 ? "" : "s"} support it`,
    );
  } else if (surv) {
    lines.push(
      `${surv.reflectionsSupporting} saved moment${surv.reflectionsSupporting === 1 ? "" : "s"} support it`,
    );
  }

  const areas = formatLifeAreas(ctx.belief.evidence.lifeAreas);
  if (areas) {
    lines.push(`Appears in ${areas}`);
  }

  if (
    lead?.previousConfidence !== undefined &&
    Math.abs(lead.confidenceDelta) >= 1
  ) {
    const prev = clampConfidence(lead.previousConfidence);
    const curr = clampConfidence(lead.confidence);
    lines.push(`Confidence ${lead.confidenceDelta > 0 ? "increased" : "changed"} from ${prev}% to ${curr}%`);
  } else {
    lines.push(`Current confidence is ${ctx.belief.confidence}%`);
  }

  if (surv) {
    lines.push(`First appeared ${surv.daysAlive} day${surv.daysAlive === 1 ? "" : "s"} ago`);
  }

  return buildAnswer("WHY", "WHY", lines, quoteLines(ctx.belief.evidence.supportingQuotes));
}

function buildSupportingEvidence(ctx: QuestionContext): ArchiveQuestionAnswer {
  const lines: string[] = [];
  const count = ctx.belief.evidence.supportingQuotes.length;
  lines.push(
    count > 0
      ? `${count} supporting excerpt${count === 1 ? "" : "s"} from saved moments on record`
      : "No supporting excerpts stored yet — the archive is still gathering evidence.",
  );
  if (ctx.belief.evidence.costEvidenceLines.length > 0) {
    lines.push("Cost and pattern lines from your saved words are included.");
  }
  return buildAnswer(
    "SHOW_EVIDENCE",
    "SUPPORTING_EVIDENCE",
    lines,
    [
      ...quoteLines(ctx.belief.evidence.supportingQuotes),
      ...ctx.belief.evidence.costEvidenceLines.slice(0, 3).map(truncateQuote),
    ],
  );
}

function buildContradictingEvidence(ctx: QuestionContext): ArchiveQuestionAnswer {
  const lines: string[] = [];
  const count = ctx.belief.evidence.contradictingQuotes.length;
  if (count === 0 && !ctx.contradiction) {
    lines.push("No contradicting excerpts are stored for this belief right now.");
  } else {
    lines.push(
      `${Math.max(count, ctx.contradiction ? 1 : 0)} contradicting signal${count === 1 ? "" : "s"} on record`,
    );
  }
  if (ctx.contradiction) {
    lines.push(ctx.contradiction.archiveExplanation);
  }
  return buildAnswer(
    "SHOW_CONTRADICTIONS",
    "CONTRADICTING_EVIDENCE",
    lines,
    quoteLines(ctx.belief.evidence.contradictingQuotes),
  );
}

function buildFirstAppeared(ctx: QuestionContext): ArchiveQuestionAnswer {
  const lines: string[] = [];
  if (ctx.survival) {
    lines.push(`First appeared on ${ctx.survival.firstAppearedDate}`);
    lines.push(
      `Tracked for ${ctx.survival.daysAlive} day${ctx.survival.daysAlive === 1 ? "" : "s"}`,
    );
  } else {
    lines.push("The archive has not pinned a first appearance date yet.");
  }
  return buildAnswer("WHEN_DID_THIS_START", "FIRST_APPEARED", lines);
}

function buildStrengthDirection(ctx: QuestionContext): ArchiveQuestionAnswer {
  const lines: string[] = [];
  const lead = ctx.leadTheory;

  if (ctx.belief.status === "strengthening") {
    lines.push("The archive marks this belief as strengthening.");
  } else if (ctx.belief.status === "weakening") {
    lines.push("The archive marks this belief as weakening.");
  } else {
    lines.push(`Status: ${ctx.belief.statusLabel}`);
  }

  if (lead?.previousConfidence !== undefined && Math.abs(lead.confidenceDelta) >= 1) {
    lines.push(
      lead.confidenceDelta > 0 ? emotionalConfidenceLine() : emotionalWeakenedLine(),
    );
    lines.push(
      `Confidence moved from ${clampConfidence(lead.previousConfidence)}% to ${clampConfidence(lead.confidence)}%`,
    );
  }

  const lastMovement = ctx.survival?.confidenceMovementHistory.at(-1);
  if (lastMovement) {
    lines.push(`${lastMovement.label}: ${lastMovement.detail}`);
  }

  return buildAnswer("IS_IT_GETTING_STRONGER", "STRENGTH_DIRECTION", lines);
}

function buildWhatChangesThis(ctx: QuestionContext): ArchiveQuestionAnswer {
  const lines: string[] = [];
  const evidence: string[] = [];

  for (const line of ctx.belief.evidence.costEvidenceLines.slice(0, 2)) {
    lines.push(truncateQuote(line));
    evidence.push(truncateQuote(line));
  }

  const areas = formatLifeAreas(ctx.belief.evidence.lifeAreas);
  if (ctx.belief.evidence.contradictingQuotes.length > 0) {
    lines.push(
      areas
        ? `Contradictions in ${areas}`
        : "Contradicting moments are on record",
    );
    evidence.push(...quoteLines(ctx.belief.evidence.contradictingQuotes).slice(0, 3));
  }

  const leadAccuracy = ctx.accuracy?.beliefs.find(
    (row) => row.theoryId === ctx.belief.theoryId,
  );
  if (leadAccuracy?.status === "challenged") {
    lines.push(
      leadAccuracy.detail ?? "Later saved moments challenged how this belief holds.",
    );
  }

  if (ctx.belief.status === "weakening") {
    lines.push("Confidence would likely decrease if the pattern continues.");
  } else if (ctx.reputation && ctx.reputation.accuracySignals === 0) {
    lines.push("More aligned follow-up moments would increase archive confidence.");
  }

  if (lines.length === 0) {
    lines.push(
      "New contradicting moments or mixed signals across life areas would shift this belief.",
    );
  }

  return buildAnswer("WHAT_WOULD_CHANGE_IT", "WHAT_CHANGES_THIS", lines, evidence);
}

function buildRecentChanges(ctx: QuestionContext): ArchiveQuestionAnswer {
  const lines = ctx.belief.changeLines.map((row) =>
    row.text.replace(/^\+\s*/, "").trim(),
  );
  if (lines.length === 0) {
    lines.push("Nothing notable has shifted in the recent archive window.");
  }
  return buildAnswer("WHAT_CHANGED_RECENTLY", "RECENT_CHANGES", lines);
}

function buildReliability(ctx: QuestionContext): ArchiveQuestionAnswer {
  const lines: string[] = [];
  if (ctx.reputation) {
    lines.push(
      trustExplanation(ctx.reputation.level, ctx.reputation.summary),
    );
    lines.push(
      `${ctx.reputation.supportingReflections} supporting moments · ${ctx.reputation.daysTracked} days tracked`,
    );
    if (ctx.reputation.contradictionsSurvived > 0) {
      lines.push(
        `Survived ${ctx.reputation.contradictionsSurvived} contradiction${ctx.reputation.contradictionsSurvived === 1 ? "" : "s"} without dropping`,
      );
    }
  } else {
    lines.push(`${ARCHIVE_TRUST_BAND_LABEL.developing} — the archive is still forming this belief.`);
  }
  return buildAnswer("HOW_RELIABLE_IS_IT", "RELIABILITY", lines);
}

function buildLifeAreas(ctx: QuestionContext): ArchiveQuestionAnswer {
  const areas = ctx.belief.evidence.lifeAreas;
  const lines: string[] = [];
  if (areas.length === 0) {
    lines.push("Life areas are not tagged for this belief yet.");
  } else {
    lines.push(`Appears across: ${areas.join(", ")}`);
    const formatted = formatLifeAreas(areas);
    if (formatted) lines.push(`Most often in ${formatted}`);
  }
  return buildAnswer("WHERE_DOES_THIS_APPEAR", "LIFE_AREAS", lines);
}

function buildImplications(_ctx: QuestionContext, entries: JournalEntry[]): ArchiveQuestionAnswer {
  const view = buildArchiveImplications(entries);
  return buildAnswer(
    "WHY_SHOULD_I_CARE",
    "IMPLICATIONS",
    implicationsAnswerLines(view),
  );
}

function buildStrongestEvidence(ctx: QuestionContext): ArchiveQuestionAnswer {
  const lines: string[] = [];
  const strongest = pickStrongestQuote(ctx.belief.evidence.supportingQuotes);
  if (strongest) {
    lines.push("Strongest supporting excerpt from your saved words:");
    return buildAnswer("STRONGEST_EVIDENCE", "STRONGEST_EVIDENCE", lines, [strongest]);
  }
  const cost = ctx.belief.evidence.costEvidenceLines[0];
  if (cost) {
    lines.push("Strongest pattern line on record:");
    return buildAnswer("STRONGEST_EVIDENCE", "STRONGEST_EVIDENCE", lines, [
      truncateQuote(cost),
    ]);
  }
  lines.push("No strongest excerpt identified yet.");
  return buildAnswer("STRONGEST_EVIDENCE", "STRONGEST_EVIDENCE", lines);
}

/**
 * Build all archive question answers from existing archive systems — no LLM.
 */
export function buildArchiveQuestionAnswers(
  entriesInput?: JournalEntry[],
): ArchiveQuestionAnswers | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const ctx = buildContext(entries);
  if (!ctx) return null;

  return {
    WHY: buildWhyAnswer(ctx),
    SUPPORTING_EVIDENCE: buildSupportingEvidence(ctx),
    CONTRADICTING_EVIDENCE: buildContradictingEvidence(ctx),
    FIRST_APPEARED: buildFirstAppeared(ctx),
    STRENGTH_DIRECTION: buildStrengthDirection(ctx),
    WHAT_CHANGES_THIS: buildWhatChangesThis(ctx),
    RECENT_CHANGES: buildRecentChanges(ctx),
    RELIABILITY: buildReliability(ctx),
    LIFE_AREAS: buildLifeAreas(ctx),
    STRONGEST_EVIDENCE: buildStrongestEvidence(ctx),
    IMPLICATIONS: buildImplications(ctx, entries),
  };
}

export function answerForQuestion(
  answers: ArchiveQuestionAnswers,
  questionId: ArchiveQuestionId,
): ArchiveQuestionAnswer {
  const key = {
    WHY: "WHY",
    SHOW_EVIDENCE: "SUPPORTING_EVIDENCE",
    SHOW_CONTRADICTIONS: "CONTRADICTING_EVIDENCE",
    WHEN_DID_THIS_START: "FIRST_APPEARED",
    IS_IT_GETTING_STRONGER: "STRENGTH_DIRECTION",
    WHAT_WOULD_CHANGE_IT: "WHAT_CHANGES_THIS",
    WHAT_CHANGED_RECENTLY: "RECENT_CHANGES",
    HOW_RELIABLE_IS_IT: "RELIABILITY",
    WHERE_DOES_THIS_APPEAR: "LIFE_AREAS",
    STRONGEST_EVIDENCE: "STRONGEST_EVIDENCE",
    WHY_SHOULD_I_CARE: "IMPLICATIONS",
  }[questionId] as ArchiveQuestionAnswerKey;

  return answers[key];
}
