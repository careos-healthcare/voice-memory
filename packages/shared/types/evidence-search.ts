export interface EvidenceSearchHit {
  id: string;
  quote: string;
  beliefText: string;
  entryId: string;
  dateLabel: string;
  lifeAreas: string[];
  matchSource: "belief" | "quote" | "reflection";
}
