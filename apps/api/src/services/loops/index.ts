import "server-only";

export { buildCuriosityHook } from "./curiosity_hook_engine";
export {
  CuriosityAdaptiveTimingEngine,
  curiosityAdaptiveTimingEngine,
} from "./curiosity_adaptive_timing_engine";
export {
  evaluateCuriosityEvidenceGate,
  recordCuriositySurface,
} from "./curiosity_evidence_gate";
export {
  buildCuriosityNotificationMessage,
  isGenericCuriosityPrompt,
} from "./curiosity_notification_message_builder";
export {
  dispatchDueCuriosityNotifications,
  queueCuriosityNotification,
} from "./curiosity_notification_scheduler";
export type {
  CuriosityEvidenceGateResult,
  CuriosityHook,
  CuriosityHookEntryMetadata,
  CuriosityHookType,
  CuriosityJournalEntryTiming,
  CuriosityNotificationMessage,
  QueuedCuriosityNotification,
} from "./types";
