export type MemoryNoteCategory = "changed" | "faded" | "returned";

export interface MemoryNote {
  id: string;
  text: string;
  pastQuote?: string;
  currentQuote?: string;
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
  hasData: boolean;
}
