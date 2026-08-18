const ARCHIVE_QUESTION_ENGAGED_KEY = "voicememory_archive_question_engaged";
const ARCHIVE_MILESTONE_ACK_KEY = "voicememory_archive_milestone_ack_id";
const ARCHIVE_MILESTONE_RETURN_DISMISS_KEY =
  "voicememory_archive_milestone_return_dismissed_at";

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return localStorage;
}

export function markArchiveQuestionEngaged(): void {
  getStorage()?.setItem(ARCHIVE_QUESTION_ENGAGED_KEY, new Date().toISOString());
}

export function hasArchiveQuestionEngaged(): boolean {
  return Boolean(getStorage()?.getItem(ARCHIVE_QUESTION_ENGAGED_KEY));
}

export function readArchiveQuestionEngagedAt(): string | null {
  return getStorage()?.getItem(ARCHIVE_QUESTION_ENGAGED_KEY) ?? null;
}

export function readAcknowledgedMilestoneId(): string | null {
  return getStorage()?.getItem(ARCHIVE_MILESTONE_ACK_KEY) ?? null;
}

export function acknowledgeMilestone(milestoneId: string): void {
  getStorage()?.setItem(ARCHIVE_MILESTONE_ACK_KEY, milestoneId);
}

export function dismissMilestoneReturnBanner(): void {
  getStorage()?.setItem(
    ARCHIVE_MILESTONE_RETURN_DISMISS_KEY,
    new Date().toISOString(),
  );
}

export function clearArchiveMilestoneStorageForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(ARCHIVE_QUESTION_ENGAGED_KEY);
  store.removeItem(ARCHIVE_MILESTONE_ACK_KEY);
  store.removeItem(ARCHIVE_MILESTONE_RETURN_DISMISS_KEY);
}
