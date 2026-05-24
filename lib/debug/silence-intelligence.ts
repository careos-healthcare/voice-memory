import { buildSilenceIntelligenceDebugReport } from "@/lib/restraint/silence-intelligence";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { SilenceIntelligenceDebugReport } from "@/types/silence-intelligence";

export function buildSilenceIntelligenceReviewReport(): SilenceIntelligenceDebugReport {
  return buildSilenceIntelligenceDebugReport(getMemoryEligibleEntries());
}
