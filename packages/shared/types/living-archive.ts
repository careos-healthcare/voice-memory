export type ArchiveLivingStatus =
  | "learning"
  | "investigating"
  | "strengthening"
  | "uncertain"
  | "revising"
  | "stable";

export type ArchiveStatusView = {
  status: ArchiveLivingStatus;
  title: string;
  label: string;
  line: string;
};

export type ArchivePulseView = {
  line: string;
};

export type ArchiveMemoryBeatLabel = "30 days ago" | "7 days ago" | "Today";

export type ArchiveMemoryBeat = {
  label: ArchiveMemoryBeatLabel;
  beliefLine: string;
  confidence: number | null;
};

export type ArchiveMemoryView = {
  beats: ArchiveMemoryBeat[];
  hasEvolution: boolean;
};

export type ArchiveOpenQuestionView = {
  id: string;
  lead: "The archive still does not know:" | "The archive is still evaluating:";
  text: string;
};

export type ArchiveReasonToReturnView = {
  line: string;
};

export type ArchiveActivityItem = {
  id: string;
  text: string;
};

export type ArchiveActivityView = {
  statusChanges: ArchiveActivityItem[];
  beliefChanges: ArchiveActivityItem[];
  evidenceChanges: ArchiveActivityItem[];
  openQuestions: ArchiveOpenQuestionView[];
};

export type LivingArchiveView = {
  status: ArchiveStatusView | null;
  pulse: ArchivePulseView | null;
  memory: ArchiveMemoryView | null;
  openQuestions: ArchiveOpenQuestionView[];
  reasonToReturn: ArchiveReasonToReturnView | null;
  activity: ArchiveActivityView;
};
