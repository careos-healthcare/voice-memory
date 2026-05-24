import { buildCallbackQualityReviewReport } from "@/lib/debug/callback-quality-review";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import {
  buildEligibleProofSnippets,
  scanOverclaimedLines,
  seedTestimonialCandidatesFromCallbacks,
} from "@/lib/social-proof/emotional-proof";
import { buildRememberedLaterReport } from "@/lib/social-proof/remembered-later";
import { buildShareObservationReport } from "@/lib/sharing/share-observation";
import {
  readAllTestimonials,
  readApprovedTestimonials,
  readRejectedTestimonials,
} from "@/lib/social-proof/testimonial-review";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { SocialProofReviewReport } from "@/types/social-proof";
import type { ShareObservationReport } from "@/types/sharing";

export function buildSocialProofReviewReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): SocialProofReviewReport {
  seedTestimonialCandidatesFromCallbacks(entries);

  const callbackReport = buildCallbackQualityReviewReport(entries);
  const loops = buildRetentionLoopReport();
  const remembered = buildRememberedLaterReport(entries);
  const approved = readApprovedTestimonials();
  const rejected = readRejectedTestimonials();
  const pending = readAllTestimonials().filter((row) => row.status === "pending");

  const strongestResidueCallbacks = [...callbackReport.items]
    .sort((a, b) => b.emotionalResidueScore - a.emotionalResidueScore)
    .slice(0, 12)
    .map((item) => ({
      id: item.id,
      text: item.text,
      score: item.emotionalResidueScore,
    }));

  const revisitStories = loops.revisitsCausingReflections.slice(0, 12).map((row) => ({
    id: row.entryId,
    text: `Revisit on ${row.entryId.slice(0, 8)}`,
    detail: row.reflectionEntryId
      ? `Led to reflection ${row.reflectionEntryId.slice(0, 8)}`
      : row.sources,
  }));

  const revisitReflectionStories = loops.revisitsCausingReflections.slice(0, 16).map((row) => ({
    entryId: row.entryId,
    reflectionEntryId: row.reflectionEntryId,
    detail: row.sources || "Revisit led to a new reflection",
  }));

  const copiedMoments = loops.copiedMomentsByNote.slice(0, 12).map((row) => ({
    id: row.noteId,
    text: row.noteText,
  }));

  const remembered72hCallbacks = remembered.rows
    .filter((row) => row.remembered72h)
    .slice(0, 12)
    .map((row) => ({ id: row.callbackId, text: row.text }));

  const shareObservation = buildShareObservationReport();

  return {
    generatedAt: new Date().toISOString(),
    hasData: callbackReport.hasData || loops.hasData,
    approvedTestimonialCandidates: [...approved, ...pending],
    rejectedGenericTestimonials: rejected,
    revisitStories,
    strongestResidueCallbacks,
    revisitReflectionStories,
    copiedMoments,
    remembered72hCallbacks,
    overclaimedEmotionalLines: scanOverclaimedLines(entries),
    quietProofSnippets: buildEligibleProofSnippets(entries),
    shareObservation,
  };
}

export function getShareObservationFromSocialProofReport(
  report: SocialProofReviewReport,
): ShareObservationReport {
  return report.shareObservation;
}

export function downloadSocialProofReviewJson(
  report: SocialProofReviewReport = buildSocialProofReviewReport(),
): void {
  if (typeof window === "undefined") return;

  const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "social-proof-review.json";
  anchor.click();
  URL.revokeObjectURL(url);
}
