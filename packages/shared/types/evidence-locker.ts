export type EvidenceLockerTag =
  | "supports"
  | "contradicts"
  | "cost"
  | "cross-area"
  | "prediction";

export interface EvidenceLockerItem {
  id: string;
  quote: string;
  entryId: string;
  dateLabel: string;
  beliefText: string;
  theoryId: string;
  tag: EvidenceLockerTag;
  whyItMatters: string;
  sortPriority: number;
}

export interface EvidenceLockerView {
  title: string;
  subtitle: string;
  items: EvidenceLockerItem[];
}
