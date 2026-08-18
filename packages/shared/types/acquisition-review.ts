import type { ClarityCheckRow, KeywordCoverageRow } from "@/lib/marketing/acquisition-restraint";
import type { ScreenshotSetId } from "@/lib/marketing/acquisition-copy";

export interface AcquisitionReviewReport {
  generatedAt: string;
  hasData: boolean;
  shortDescription: string;
  fullDescription: string;
  appStoreKeywords: string;
  playStoreKeywords: readonly string[];
  bannedAbstractHits: Array<{ phrase: string; where: string }>;
  keywordCoverage: KeywordCoverageRow[];
  keywordCoveragePercent: number;
  screenshotSets: Array<{
    id: ScreenshotSetId;
    label: string;
    headlines: readonly string[];
    clarityRows: ClarityCheckRow[];
  }>;
  onboardingHookChecks: ClarityCheckRow[];
  trustLineChecks: ClarityCheckRow[];
  averageEmotionalClarityScore: number;
  comprehensionSummary: ReturnType<
    typeof import("@/lib/marketing/first-session-comprehension").readFirstSessionComprehensionSummary
  >;
  confusionRisks: string[];
  emotionalClarityIssues: string[];
}

export interface FounderAcquisitionExport {
  exportedAt: string;
  positioning: {
    shortDescription: string;
    fullDescription: string;
    appStoreKeywords: string;
    playStoreKeywords: string[];
  };
  screenshotCopy: Record<ScreenshotSetId, string[]>;
  asoKeywords: {
    appStore: string;
    playStore: string[];
    coveragePercent: number;
  };
  trustCopy: string[];
  onboardingHooks: string[];
  confusionRisks: string[];
  emotionalClarityIssues: string[];
  firstSessionComprehension: AcquisitionReviewReport["comprehensionSummary"];
  reviewResponseTemplates: Record<string, string>;
}
