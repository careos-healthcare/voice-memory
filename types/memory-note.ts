export type MemoryNoteCategory = "changed" | "faded" | "returned";

export interface MemoryNote {
  id: string;
  text: string;
  pastQuote?: string;
  currentQuote?: string;
  pastDateLabel?: string;
  currentDateLabel?: string;
  entryId?: string;
  pastEntryId?: string;
  category: MemoryNoteCategory;
  confidence: number;
  /** Quiet evidence line for resurfacing — never a numeric score. */
  evidenceReason?: string;
}

export interface MemoryNotesReport {
  changed: MemoryNote[];
  faded: MemoryNote[];
  returned: MemoryNote[];
  all: MemoryNote[];
  landmarks: MemoryNote[];
  hasData: boolean;
}
