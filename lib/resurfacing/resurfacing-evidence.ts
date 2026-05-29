import { assessResurfacingConfidence } from "@/lib/revisit/resurfacing-confidence";
import { assessResurfacingWhyNow } from "@/lib/revisit/resurfacing-why-now";
import { buildEntityMemoryFromEntries } from "@/lib/entity-memory";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { assessConcreteResurfacingEvidence } from "@/lib/resurfacing/evidence-engine";
import { assessResurfacingAmbiguity } from "@/lib/resurfacing/resurfacing-ambiguity";
import { detectResurfacingContradiction } from "@/lib/resurfacing/resurfacing-contradictions";
import { getMergedFeedbackSummary } from "@/lib/resurfacing/merged-feedback-client";
import {
  personKeyFromQuote,
  phraseKeyFromQuote,
  topicKeyFromQuote,
} from "@/lib/resurfacing/resurfacing-feedback";
import type { ResurfacingFeedbackSummary } from "@/lib/resurfacing/resurfacing-feedback-summary";
import {
  buildResurfacingScores,
  type ResurfacingScoreBreakdown,
} from "@/lib/resurfacing/resurfacing-scoring";
import {
  rejectionPenaltyForPhrase,
  resolveCooldownStatus,
  stalenessConfidencePenalty,
} from "@/lib/resurfacing/resurfacing-staleness";
import { getResurfacingFatiguePenalty } from "@/lib/resurfacing/resurfacing-fatigue";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type { ResurfacingEvidence } from "@/types/resurfacing-evidence";
import type { ReturnThread } from "@/types/return-thread";

export interface BuildResurfacingEvidenceInput {
  quote: string;
  entries?: JournalEntry[];
  note?: MemoryNote;
  appearances?: number;
  gapDays?: number;
  threadType?: ReturnThread["type"];
  scores?: ResurfacingScoreBreakdown;
  feedbackSummary?: ResurfacingFeedbackSummary;
  missingTranscript?: boolean;
}

function gapDaysForNote(note: MemoryNote, entries: JournalEntry[]): number {
  const past = entries.find((e) => e.id === note.pastEntryId);
  const current = entries.find((e) => e.id === note.entryId);
  if (!past || !current) return 0;
  return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
}

function collectEvidenceAnchors(
  input: BuildResurfacingEvidenceInput,
): Pick<
  ResurfacingEvidence,
  | "exactQuoteMatches"
  | "repeatedPhrases"
  | "sharedPeople"
  | "sharedTopics"
  | "sharedTimeWindow"
  | "emotionalShift"
> {
  const quote = input.quote.replace(/^["']|["']$/g, "").trim();
  const exactQuoteMatches: string[] = [];
  const repeatedPhrases: string[] = [];
  const sharedPeople: string[] = [];
  const sharedTopics: string[] = [];
  let sharedTimeWindow: string | null = null;
  let emotionalShift: string | null = null;

  if (quote.length >= 8) exactQuoteMatches.push(quote);

  if (input.entries?.length && input.note) {
    const concrete = assessConcreteResurfacingEvidence(input.note, input.entries);
    const confidence = assessResurfacingConfidence(input.note, input.entries);
    const whyNow = assessResurfacingWhyNow(input.note, input.entries);

    if (confidence.evidence.repeatedPhrase) {
      for (const record of buildPhraseMemory(input.entries)) {
        if (record.count >= 2 && record.phrase.length >= 6) {
          repeatedPhrases.push(record.phrase);
          break;
        }
      }
    }

    for (const entity of confidence.evidence.sharedEntities.slice(0, 3)) {
      if (entity.length >= 2) sharedPeople.push(entity);
    }

    if (whyNow.primaryKind === "named_person_topic_return") {
      const memory = buildEntityMemoryFromEntries(input.entries);
      for (const row of memory.topics.slice(0, 2)) {
        if (row.name) sharedTopics.push(row.name);
      }
    }

    const gap = gapDaysForNote(input.note, input.entries);
    if (gap >= 7) {
      sharedTimeWindow = `${gap} days between these entries`;
    } else if (confidence.evidence.daysSincePrior >= 3) {
      sharedTimeWindow = "a few days apart";
    }

    if (concrete.kinds.includes("mood_shift")) {
      emotionalShift = "the tone shifted on the same topic";
    }

    const pastQ = input.note.pastQuote?.trim() ?? "";
    const curQ = input.note.currentQuote?.trim() ?? quote;
    const contradiction = detectResurfacingContradiction(pastQ, curQ);
    if (contradiction.changeLine) emotionalShift = contradiction.changeLine;
  } else if (input.entries?.length) {
    for (const record of buildPhraseMemory(input.entries)) {
      if (record.count >= (input.appearances ?? 2) && record.phrase.length >= 6) {
        repeatedPhrases.push(record.phrase);
        break;
      }
    }
    const person = personKeyFromQuote(quote);
    if (person) sharedPeople.push(person);
    if (input.gapDays !== undefined && input.gapDays >= 7) {
      sharedTimeWindow = `${input.gapDays} days between mentions`;
    }
  }

  if (input.appearances !== undefined && input.appearances >= 2 && quote.length >= 10) {
    if (!repeatedPhrases.includes(quote)) repeatedPhrases.push(quote);
  }

  const topicKey = topicKeyFromQuote(quote);
  if (topicKey && !sharedTopics.includes(topicKey)) {
    sharedTopics.push(topicKey);
  }

  return {
    exactQuoteMatches,
    repeatedPhrases,
    sharedPeople,
    sharedTopics,
    sharedTimeWindow,
    emotionalShift,
  };
}

export function buildResurfacingEvidence(
  input: BuildResurfacingEvidenceInput,
): ResurfacingEvidence {
  const quote = input.quote.trim();
  const phraseKey = phraseKeyFromQuote(quote);
  const topicKey = topicKeyFromQuote(quote);
  const personKey = personKeyFromQuote(quote);

  const anchors = collectEvidenceAnchors(input);
  const summary =
    input.feedbackSummary ?? getMergedFeedbackSummary(phraseKey, topicKey, personKey);

  const ambiguity = assessResurfacingAmbiguity(quote, {
    missingTranscript: input.missingTranscript ?? quote.length === 0,
  });

  let contradictionSignal: string | null = null;
  if (input.note?.pastQuote && input.note.currentQuote) {
    const c = detectResurfacingContradiction(
      input.note.pastQuote,
      input.note.currentQuote,
    );
    contradictionSignal = c.signal;
    if (c.changeLine && !anchors.emotionalShift) {
      anchors.emotionalShift = c.changeLine;
    }
  }

  const scores =
    input.scores ??
    buildResurfacingScores({
      quote,
      appearances: input.appearances ?? 2,
      gapDays: input.gapDays,
      threadType: input.threadType,
    });

  const priorUserRejection = phraseKey ? (summary.phrasePenalties[phraseKey] ?? 0) : 0;
  const priorUserAcceptance = phraseKey ? (summary.acceptanceBoosts[phraseKey] ?? 0) : 0;
  const stalenessDays = input.gapDays ?? (input.note && input.entries?.length
    ? gapDaysForNote(input.note, input.entries)
    : 0);

  const feedbackPenalties: string[] = [];
  const feedbackBoosts: string[] = [];
  if (priorUserRejection > 0) feedbackPenalties.push("prior rejection");
  if ((summary.topicPenalties[topicKey] ?? 0) > 0) {
    feedbackPenalties.push("wrong topic feedback");
  }
  if (personKey && (summary.personPenalties[personKey] ?? 0) > 0) {
    feedbackPenalties.push("wrong person feedback");
  }
  if (priorUserAcceptance > 0) feedbackBoosts.push("that fits");

  let cooldownStatus = resolveCooldownStatus({
    phraseKey,
    noteId: input.note?.id,
    stalenessDays,
    priorRejection: priorUserRejection,
  });
  if (phraseKey && summary.clusterRetired[phraseKey]) cooldownStatus = "retired";
  if (
    phraseKey &&
    summary.clusterCooldownUntil[phraseKey] &&
    Date.parse(summary.clusterCooldownUntil[phraseKey]!) > Date.now()
  ) {
    cooldownStatus = "cooldown";
  }

  const hasAnchor =
    anchors.exactQuoteMatches.length > 0 ||
    anchors.repeatedPhrases.length > 0 ||
    anchors.sharedPeople.length > 0 ||
    anchors.sharedTopics.length > 0 ||
    Boolean(anchors.sharedTimeWindow);

  let evidenceScore = 0;
  if (anchors.exactQuoteMatches.length) evidenceScore += 32;
  if (anchors.repeatedPhrases.length) evidenceScore += 28;
  if (anchors.sharedPeople.length) evidenceScore += 22;
  if (anchors.sharedTopics.length) evidenceScore += 14;
  if (anchors.sharedTimeWindow) evidenceScore += 12;
  if (anchors.emotionalShift) evidenceScore += 16;
  if (contradictionSignal) evidenceScore += 10;
  evidenceScore += Math.min(scores.quoteMatchScore * 0.25, 22);
  evidenceScore += Math.min(scores.recurrenceScore * 0.2, 18);

  const fatiguePenalty = input.note?.id
    ? getResurfacingFatiguePenalty(input.note.id)
    : 0;
  const stalePenalty = stalenessConfidencePenalty(stalenessDays);
  const specificityBoost = summary.specificityThresholdBoost;
  const minEvidenceForShow = 28 + Math.min(specificityBoost, 24);

  let finalConfidence =
    scores.finalResurfacingConfidence +
    priorUserAcceptance * 0.4 -
    (summary.topicPenalties[topicKey] ?? 0) * 0.35 -
    (personKey ? (summary.personPenalties[personKey] ?? 0) : 0) * 0.4 -
    stalePenalty -
    fatiguePenalty * 0.5;

  if (!hasAnchor) finalConfidence = Math.min(finalConfidence, 40);
  if (ambiguity.ambiguityScore >= 55) finalConfidence -= 12;
  if (summary.intensityCautious) finalConfidence -= 6;

  finalConfidence = Math.max(0, Math.min(100, Math.round(finalConfidence)));
  evidenceScore = Math.max(0, Math.min(100, Math.round(evidenceScore)));

  const suppressionReasons: string[] = [];
  if (!hasAnchor) suppressionReasons.push("no_concrete_evidence");
  if (evidenceScore < minEvidenceForShow) suppressionReasons.push("weak_evidence_score");
  if (priorUserRejection >= 35) suppressionReasons.push("not_me_retired");
  if (cooldownStatus === "cooldown") suppressionReasons.push("feedback_cooldown");
  if (cooldownStatus === "retired") suppressionReasons.push("cluster_retired");
  if (cooldownStatus === "fatigued") suppressionReasons.push("fatigued");
  if (priorUserRejection >= 35) suppressionReasons.push("phrase_penalty");

  return {
    ...anchors,
    contradictionSignal,
    ambiguitySignal: ambiguity.vaguenessSignal ?? (ambiguity.ambiguityScore >= 40 ? "high ambiguity" : null),
    sarcasmSignal: ambiguity.sarcasmSignal,
    vaguenessSignal: ambiguity.vaguenessSignal,
    priorUserAcceptance,
    priorUserRejection,
    stalenessDays,
    cooldownStatus,
    feedbackPenalties,
    feedbackBoosts,
    finalConfidence,
    evidenceScore,
    suppressionReasons,
    cautiousWordingRequired:
      ambiguity.cautiousWordingRequired ||
      summary.intensityCautious ||
      finalConfidence < 68,
  };
}

export function hasResurfacingEvidenceAnchors(evidence: ResurfacingEvidence): boolean {
  return (
    evidence.exactQuoteMatches.length > 0 ||
    evidence.repeatedPhrases.length > 0 ||
    evidence.sharedPeople.length > 0 ||
    evidence.sharedTopics.length > 0 ||
    evidence.sharedTimeWindow !== null
  );
}
