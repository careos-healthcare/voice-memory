import type { FalsePositiveReason, FalsePositiveSourceModule } from "@/types/false-positive-suppression";

export interface SuppressionReviewItem {
  id: string;
  text: string;
  sourceModule: FalsePositiveSourceModule;
  suppressed: boolean;
  reasons: FalsePositiveReason[];
  missingEvidence: string[];
  candidateText: string;
  hierarchyScore?: number;
}

export interface SuppressionReviewReport {
  hasData: boolean;
  totalCandidates: number;
  suppressedCount: number;
  surfacedCount: number;
  byReason: Partial<Record<FalsePositiveReason, number>>;
  items: SuppressionReviewItem[];
}
