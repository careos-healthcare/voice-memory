export type TheoryNotificationType =
  | "strengthened"
  | "weakened"
  | "resolved"
  | "retired"
  | "new_evidence"
  | "contradiction"
  | "prediction_outcome";

export type TheoryNotificationImportance = "low" | "medium" | "high";

export type TheoryNotificationRoute = "/discover" | "/theories";

export interface TheoryNotification {
  id: string;
  theoryId: string;
  type: TheoryNotificationType;
  title: string;
  body: string;
  createdAt: string;
  readAt?: string;
  importance: TheoryNotificationImportance;
  relatedRoute: TheoryNotificationRoute;
  evidenceSummary: string;
  confidenceDelta?: number;
  /** Stable key for deduplication: theory + type + evidence ids */
  dedupeKey: string;
}

export interface TheoryNotificationGenerationReport {
  generatedAt: string;
  hasBaseline: boolean;
  created: TheoryNotification[];
  skippedFirstVisit: boolean;
}
