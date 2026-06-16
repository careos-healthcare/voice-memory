export type ArchiveVoiceScopeId =
  | "blind_spots"
  | "discover"
  | "theories"
  | "updates"
  | "archive_value";

export type ArchiveVoiceViolationCategory = "coaching" | "motivational" | "therapy";

export interface ArchiveVoiceViolation {
  file: string;
  line: number;
  category: ArchiveVoiceViolationCategory;
  match: string;
  excerpt: string;
}

export interface ArchiveVoiceScopeResult {
  id: ArchiveVoiceScopeId;
  label: string;
  filesScanned: number;
  violations: ArchiveVoiceViolation[];
  preferredSignalsFound: string[];
}

export interface ArchiveVoiceConsistencyReport {
  title: string;
  generatedAt: string;
  pass: boolean;
  scopes: ArchiveVoiceScopeResult[];
  totalViolations: number;
  summaryLines: string[];
}
