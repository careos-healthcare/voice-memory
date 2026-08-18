import type { ArchiveReputationLevel } from "@/types/archive-reputation";

export type ArchiveStateSnapshot = {
  belief: string;
  confidence: number;
  reputation: ArchiveReputationLevel;
  evidenceCount: number;
  lifeAreas: string[];
  timestamp: string;
};

export type ArchiveStateDeltaRowKind =
  | "confidence"
  | "evidence"
  | "life_areas"
  | "reputation"
  | "belief";

export type ArchiveStateDeltaRow = {
  kind: ArchiveStateDeltaRowKind;
  label: string;
  then: string;
  now: string;
  difference: string;
};

export type ArchiveStateDeltaView = {
  hasChanges: boolean;
  rows: ArchiveStateDeltaRow[];
  awayReturn: boolean;
  headline: string;
  subheadline: string | null;
  generatedAt: string;
};

export type ArchiveStateDeltaHistoryEntry = {
  id: string;
  recordedAt: string;
  delta: ArchiveStateDeltaView;
};
