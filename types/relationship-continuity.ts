export type RelationshipContinuityKind =
  | "appeared_more"
  | "appeared_less"
  | "language_calmer"
  | "language_more_direct"
  | "person_quiet"
  | "first_named"
  | "topic_around_changed";

export type RelationshipContinuityContext = "memory" | "threads" | "entry";

export interface RelationshipContinuityNote {
  id: string;
  kind: RelationshipContinuityKind;
  text: string;
  entityName: string;
  strength: number;
  entryId?: string;
  pastEntryId?: string;
  href?: string;
}

export interface RelationshipContinuityReport {
  notes: RelationshipContinuityNote[];
  hasData: boolean;
}

export interface RelationshipContinuityCopyExample {
  kind: RelationshipContinuityKind;
  message: string;
  whenShown: string;
}
