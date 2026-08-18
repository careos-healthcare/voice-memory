import type { BlindSpotEvidenceQuote } from "@/types/blind-spot";

export type MiniWowTier =
  | "first"
  | "none"
  | "echo"
  | "forming"
  | "preview"
  | "unlocked";

export type MiniWowClueType =
  | "none"
  | "repeated_phrase"
  | "repeated_theme"
  | "emerging_pattern"
  | "scorecard_ingredient";

export interface MiniWowReport {
  tier: MiniWowTier;
  reflectionCount: number;
  progressLabel: string;
  panelTitle: string;
  disclaimer: string;
  title: string;
  body: string;
  clueType: MiniWowClueType;
  confidenceLabel?: string;
  evidenceQuotes: BlindSpotEvidenceQuote[];
  showPanel: boolean;
}
