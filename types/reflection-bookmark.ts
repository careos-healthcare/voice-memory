export type ReflectionBookmarkType = "mattered" | "revisit_later" | "changed_something";

export interface ReflectionBookmark {
  entryId: string;
  type: ReflectionBookmarkType;
  markedAt: string;
}

export interface ReflectionBookmarkWithEntry extends ReflectionBookmark {
  dateLabel: string;
  snippet: string;
  href: string;
}
