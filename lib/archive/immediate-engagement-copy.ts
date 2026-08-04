import type { ImmediateNoticeKind } from "@/types/immediate-engagement";

export const IMMEDIATE_ENGAGEMENT_HEADING = "What ArchiveMe noticed";

export const IMMEDIATE_NOTICE_CATEGORY: Record<ImmediateNoticeKind, string> = {
  repeated_phrase: "Repeated phrase",
  possible_pattern: "Possible pattern",
  theory_movement: "Theory movement",
  confidence_change: "Confidence change",
  contradiction: "Contradiction",
  new_evidence: "New evidence",
};

export const IMMEDIATE_FOLLOWUP_BY_KIND: Record<ImmediateNoticeKind, string> = {
  repeated_phrase:
    "This appears similar to something you said before. Was the situation similar too?",
  possible_pattern:
    "You have described this reaction more than once. Do you think the cause was the same?",
  theory_movement: "This may support an existing theory. Does that feel right?",
  confidence_change: "This may support an existing theory. Does that feel right?",
  contradiction:
    "Your archive now has evidence pointing in two directions. Does that match how it felt?",
  new_evidence:
    "This moment adds to what your archive already tracks. Does that connection feel fair?",
};

import { ARCHIVE_VOICE_FORBIDDEN_UNIFIED } from "@/lib/archive/archive-voice";

/** Archive clarification only — must not read as coaching or therapy. */
export const IMMEDIATE_ENGAGEMENT_FORBIDDEN = ARCHIVE_VOICE_FORBIDDEN_UNIFIED;
