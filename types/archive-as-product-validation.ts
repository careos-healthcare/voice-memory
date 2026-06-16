export type ArchiveAsProductVerdict = "strong" | "weak" | "mixed" | "insufficient_data";

export type ProductDescriptionCategory =
  | "archive_model"
  | "insight_tool"
  | "journal_mode"
  | "mixed"
  | "unclear";

export interface ArchiveAsProductCriterionRow {
  id: string;
  rank: number;
  title: string;
  question: string;
  interviewRate: number | null;
  deviceRate: number | null;
  passThresholdPercent: number;
  verdict: ArchiveAsProductVerdict;
  passMeaning: string;
  failMeaning: string;
}

export interface ArchiveAsProductValidationReport {
  mainQuestion: string;
  verdict: ArchiveAsProductVerdict;
  verdictAnswer: string;
  criteria: ArchiveAsProductCriterionRow[];
  interviewCount: number;
  pausedBuilds: string[];
  buildIfValidated: string[];
  explicitlyNot: string[];
}
