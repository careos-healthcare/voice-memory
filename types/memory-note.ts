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
}

export interface MemoryNotesReport {
  changed: MemoryNote[];
  faded: MemoryNote[];
  returned: MemoryNote[];
  all: MemoryNote[];
  landmarks: MemoryNote[];
  hasData: boolean;
}
