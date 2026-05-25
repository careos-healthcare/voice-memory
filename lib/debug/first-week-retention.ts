import { readLocalEvents } from "@/lib/local-analytics";
import { countFirstWeekEvents } from "@/lib/retention/first-week-observation";
import { pickArchiveValueMoment } from "@/lib/retention/archive-value-moments";
import { assessArchiveAttachment } from "@/lib/retention/archive-attachment-signals";
import { previewGentleReturnPrompt } from "@/lib/retention/gentle-return-prompts";
import {
  buildFirstWeekTimingRecommendations,
  detectFirstWeekMilestones,
  firstRevisitDelayHours,
  firstSessionComplete,
  firstWeekDayIndex,
  isWithinFirstWeek,
  readFirstWeekPromptState,
} from "@/lib/retention/first-week";
import { pickFirstMeaningfulRevisitCandidate } from "@/lib/revisit/first-meaningful-revisit";
import { resolveSilenceIntelligence } from "@/lib/restraint/silence-intelligence";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { FirstWeekRetentionDebugReport } from "@/types/first-week-retention";

function revisitConversionLabel(): string {
  const loops = readRetentionLoopEvents();
  const revisits = loops.filter((e) => e.kind === "entry_revisited").length;
  const reflections = loops.filter((e) => e.kind === "followup_recording_completed").length;
  if (revisits === 0) return "No revisits yet";
  if (reflections === 0) return `${revisits} revisit(s) · no follow-up recording yet`;
  return `${revisits} revisit(s) · ${reflections} follow-up recording(s)`;
}

function retentionRisks(
  entries: ReturnType<typeof getMemoryEligibleEntries>,
  attachmentLevel: string,
  ignored: number,
): string[] {
  const risks: string[] = [];
  if (entries.length === 0) risks.push("No reflections — archive not started");
  if (entries.length === 1) risks.push("Single reflection — weak continuity signal");
  if (attachmentLevel === "weak" && entries.length >= 2) {
    risks.push("Multiple reflections but attachment still weak");
  }
  if (ignored >= 2) risks.push("Gentle prompts ignored repeatedly — stay silent");
  const silence = resolveSilenceIntelligence(entries);
  if (silence.state === "almost_silent") risks.push("Silence intelligence almost_silent");
  const events = readLocalEvents();
  if (events.some((e) => e.name === "revisit_emotional_payoff")) {
    return risks;
  }
  if (entries.length >= 2 && !events.some((e) => e.name === "first_revisit_completed")) {
    risks.push("No meaningful revisit payoff recorded yet");
  }
  return risks;
}

export function buildFirstWeekRetentionDebugReport(): FirstWeekRetentionDebugReport {
  const entries = getMemoryEligibleEntries();
  const milestones = detectFirstWeekMilestones(entries);
  const attachment = assessArchiveAttachment(entries);
  const candidate = pickFirstMeaningfulRevisitCandidate(entries);
  const promptState = readFirstWeekPromptState();
  const silence = resolveSilenceIntelligence(entries);

  return {
    generatedAt: new Date().toISOString(),
    withinFirstWeek: isWithinFirstWeek(entries),
    dayIndex: firstWeekDayIndex(entries),
    milestones,
    timingRecommendations: buildFirstWeekTimingRecommendations(entries),
    attachmentLevel: attachment.level,
    attachmentEvidence: attachment.evidenceLines,
    firstSessionComplete: firstSessionComplete(entries),
    firstRevisitDelayHours: firstRevisitDelayHours(entries),
    revisitConversion: revisitConversionLabel(),
    attachmentEmergence: `${attachment.level} · ${attachment.signals.length} internal signals`,
    ignoredPromptCount: promptState.ignoredCount,
    promptsShownThisWeek: promptState.shownThisWeek,
    silenceEffective:
      Boolean(silence.returnAfterSilence) ||
      countFirstWeekEvents().silence_helped_return > 0,
    retentionRisks: retentionRisks(entries, attachment.level, promptState.ignoredCount),
    emotionalPayoffCandidates: candidate
      ? [
          {
            entryId: candidate.entryId,
            score: candidate.payoffScore,
            firstLine: candidate.firstLine,
            signals: candidate.signals,
          },
        ]
      : [],
    instrumentation: countFirstWeekEvents(),
    activeGentlePrompt: previewGentleReturnPrompt(entries),
    activeArchiveValueLine: null,
  };
}
