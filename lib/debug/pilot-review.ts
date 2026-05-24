import { buildArchiveMaturityReport } from "@/lib/debug/archive-maturity-review";
import { buildEmotionalLegitimacyReport } from "@/lib/debug/emotional-legitimacy-review";
import { buildArchiveAttachmentReport } from "@/lib/research/archive-attachment";
import { readWillingnessFounderLabels } from "@/lib/research/willingness-signals";
import { readPilotFounderLabels, buildPilotInterestReport } from "@/lib/pilot/pilot-interest";
import { buildPilotAccessReport } from "@/lib/pilot/pilot-access";
import { evaluatePilotRestraint, pilotSuppressionLabel } from "@/lib/pilot/pilot-restraint";
import { buildMonetizationObservationReport } from "@/lib/monetization/monetization-observation";
import {
  getOrCreateParticipantId,
  readStudyParticipantRoster,
} from "@/lib/research/retention-observation";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { PilotCandidateRow, PilotReviewReport } from "@/types/pilot-system";

function candidate(
  participantId: string,
  label: string,
  detail: string,
  score: number,
): PilotCandidateRow {
  return { id: participantId, participantId, label, detail, score };
}

/** Founder pilot review — debug only. */
export async function buildPilotReviewReport(): Promise<PilotReviewReport> {
  const entries = getMemoryEligibleEntries();
  const attachment = buildArchiveAttachmentReport(entries);
  const maturity = buildArchiveMaturityReport(entries);
  const loops = buildRetentionLoopReport();
  const legitimacy = buildEmotionalLegitimacyReport(entries);
  const interest = buildPilotInterestReport();
  const access = buildPilotAccessReport();
  const restraint = await evaluatePilotRestraint();
  const observation = buildMonetizationObservationReport();
  const roster = readStudyParticipantRoster();

  const strongestAttachment: PilotCandidateRow[] = attachment.signals
    .slice(0, 8)
    .map((row) => candidate(row.id, row.label, row.detail, row.strength));

  const safestPilotCandidates: PilotCandidateRow[] = roster
    .map((participant) => {
      const pilotLabel = readPilotFounderLabels(participant.id)[0];
      const wtp = readWillingnessFounderLabels(participant.id)[0];
      let score = attachment.attachmentScore / 2;
      if (pilotLabel?.label === "likely_early_supporter") score += 25;
      if (pilotLabel?.label === "highly_attached") score += 20;
      if (wtp?.label === "would_pay") score += 15;
      if (pilotLabel?.label === "not_ready" || pilotLabel?.label === "trust_sensitive") score -= 30;
      return candidate(
        participant.id,
        participant.label ?? participant.id.slice(0, 8),
        pilotLabel?.label ?? "No founder label",
        Math.round(score),
      );
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, 10);

  const trustRiskUsers: PilotCandidateRow[] = roster
    .filter((participant) => {
      const label = readPilotFounderLabels(participant.id)[0];
      return label?.label === "trust_sensitive" || label?.label === "not_ready";
    })
    .map((participant) =>
      candidate(
        participant.id,
        participant.label ?? participant.id.slice(0, 8),
        readPilotFounderLabels(participant.id)[0]?.note ?? "Trust-sensitive or not ready",
        40,
      ),
    );

  const willingnessEvolution = [
    ...readWillingnessFounderLabels(getOrCreateParticipantId()).slice(0, 4).map((row) => ({
      at: row.createdAt.slice(0, 10),
      label: row.label,
      detail: row.note ?? "WTP label",
    })),
    ...readPilotFounderLabels().slice(0, 4).map((row) => ({
      at: row.createdAt.slice(0, 10),
      label: row.label,
      detail: row.note ?? "Pilot label",
    })),
  ];

  return {
    generatedAt: new Date().toISOString(),
    hasData: attachment.hasData || interest.hasData || access.roster.length > 0,
    strongestAttachment,
    safestPilotCandidates,
    trustRiskUsers,
    archiveMaturity: maturity.archiveDepth.densityScore,
    revisitDepth: loops.revisitsCausingReflections.length + loops.notesCausingRevisits.length,
    willingnessEvolution,
    monetizationLegitimacy: legitimacy.scores.overall,
    trustImpactAfterExposure: {
      before: observation.legitimacyBeforeExposure,
      after: observation.legitimacyAfterExposure,
    },
    interest,
    access,
    restraint,
  };
}

export function downloadPilotReviewJson(report: PilotReviewReport): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "pilot-review.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

export { pilotSuppressionLabel };
