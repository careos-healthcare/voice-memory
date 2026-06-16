/** Archive Reduction v3 — single user-facing archive read model. */

export type ArchiveHealthLabel = "Strong" | "Developing" | "Uncertain";

export type ArchiveStateObject = {
  belief: string;
  confidence: number;
  evidenceSummary: string;
  changeSummary: string;
  watchItem: string;
  health: ArchiveHealthLabel;
};
