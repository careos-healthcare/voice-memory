export const RETURN_TRIGGER_EVENT_NAMES = [
  "return_after_photo",
  "return_after_revisit",
  "return_after_roundup",
  "return_after_territory",
  "return_after_silence",
  "return_after_backup",
  "return_after_archive_export",
  "return_after_first_callback",
  "return_after_prompt",
  "return_without_prompt",
] as const;

export type ReturnTriggerEventName = (typeof RETURN_TRIGGER_EVENT_NAMES)[number];

export type ReturnTriggerKind =
  | "photo"
  | "revisit"
  | "roundup"
  | "territory"
  | "silence"
  | "backup"
  | "archive_export"
  | "first_callback"
  | "prompt";

export interface ReturnTriggerReturnRow {
  eventName: ReturnTriggerEventName;
  at: string;
  triggerKind: ReturnTriggerKind | "voluntary" | null;
  hoursSinceTrigger: number | null;
  hoursSinceLastOpen: number | null;
  window: string | null;
  ledToReflection: boolean;
  ledToRevisit: boolean;
  ledToExportOrBackup: boolean;
}

export interface ReturnTriggerCategorySummary {
  kind: ReturnTriggerKind | "voluntary";
  eventName: ReturnTriggerEventName;
  count: number;
  medianHoursToReturn: number | null;
  reflectionRate: number;
  revisitRate: number;
  exportOrBackupRate: number;
  strength: "strong" | "moderate" | "weak" | "noisy" | "none";
}

export interface ReturnTriggerDebugReport {
  generatedAt: string;
  hasData: boolean;
  totalReturns: number;
  instrumentation: Record<string, number>;
  strongestTriggers: ReturnTriggerCategorySummary[];
  weakOrNoisyTriggers: ReturnTriggerCategorySummary[];
  promptDrivenCount: number;
  voluntaryCount: number;
  silenceDriven: ReturnTriggerCategorySummary;
  photoDriven: ReturnTriggerCategorySummary;
  territoryDriven: ReturnTriggerCategorySummary;
  revisitDriven: ReturnTriggerCategorySummary;
  recentReturns: ReturnTriggerReturnRow[];
}
