export type ConversationThreadSource = "theme" | "person" | "phrase" | "topic";

export interface ConversationThreadEntry {
  entryId: string;
  dateLabel: string;
  snippet: string;
}

export interface ConversationThreadEvolution {
  whatChanged: string | null;
  whatFaded: string | null;
  whatCameBack: string | null;
}

export interface ConversationThread {
  id: string;
  slug: string;
  title: string;
  source: ConversationThreadSource;
  entryIds: string[];
  firstAppearance: string;
  latestAppearance: string;
  firstAppearanceLabel: string;
  latestAppearanceLabel: string;
  mentionCount: number;
  relatedEntries: ConversationThreadEntry[];
  evolution: ConversationThreadEvolution;
}

export interface ConversationThreadReport {
  threads: ConversationThread[];
  hasData: boolean;
}
