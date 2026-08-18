export type ImmediateNoticeKind =
  | "repeated_phrase"
  | "possible_pattern"
  | "theory_movement"
  | "confidence_change"
  | "contradiction"
  | "new_evidence";

export type ArchiveFollowupAnswerValue = "yes" | "no" | "not_sure" | "skip";

export interface ImmediateEngagementPayload {
  id: string;
  entryId: string;
  generatedAt: string;
  noticeKind: ImmediateNoticeKind;
  noticeCategory: string;
  noticeDetail: string;
  followUpId: string;
  followUpQuestion: string;
}

export interface ArchiveFollowupAnswerRecord {
  id: string;
  followUpId: string;
  entryId: string;
  noticeKind: ImmediateNoticeKind;
  answer: ArchiveFollowupAnswerValue;
  at: string;
}

export type ImmediateEngagementEventName = "followup_shown" | "followup_answered";

export interface ImmediateEngagementEvent {
  name: ImmediateEngagementEventName;
  at: string;
  followUpId: string;
  entryId: string;
  noticeKind: ImmediateNoticeKind;
}
