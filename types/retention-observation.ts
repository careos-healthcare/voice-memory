export type WouldPayAnswer = "yes" | "no" | "maybe";

export interface ManualStudyNote {
  id: string;
  createdAt: string;
  rememberedSentence48h?: string;
  feltRemembered?: boolean;
  feltGeneric?: boolean;
  userQuote?: string;
  wouldPay?: WouldPayAnswer;
  payReason?: string;
}

export interface RetentionWindowIndicator {
  windowDays: 7 | 30 | 60;
  eligible: boolean;
  activeReturnDays: number;
  returnedAfterFirstUse: boolean;
  oldEntryRevisits: number;
  revisitToReflection: number;
  followupsStarted: number;
  followupsCompleted: number;
  bookmarks: number;
  copiedMoments: number;
}

export interface RevisitFunnelStep {
  step: string;
  count: number;
}

export interface ArchiveProtectionBehavior {
  exportUsed: boolean;
  encryptedBackupConfigured: boolean;
  localExportUsed: boolean;
  backupConfigured: boolean;
  exportCount: number;
}

export interface ParticipantSnapshot {
  participantId: string;
  studyAnchorDay: string;
  studyDayCount: number;
  returnDayCount: number;
  reflectionCount: number;
  archiveSpanDays: number | null;
}

export interface RetentionObservationSnapshot {
  generatedAt: string;
  participant: ParticipantSnapshot;
  returnDayKeys: string[];
  retentionWindows: RetentionWindowIndicator[];
  revisitFunnel: RevisitFunnelStep[];
  archiveProtection: ArchiveProtectionBehavior;
  emotionalResidue: ManualStudyNote[];
  automated: {
    oldEntryRevisits: number;
    memoryNoteToOldEntryOpens: number;
    revisitToReflectionLinks: number;
    followupsStarted: number;
    followupsCompleted: number;
    bookmarks: number;
    copiedMoments: number;
    day1Returns: number;
    day7Returns: number;
  };
}

export interface AnonymizedStudyExport {
  schemaVersion: 1;
  exportedAt: string;
  participantId: string;
  observation: RetentionObservationSnapshot;
}
