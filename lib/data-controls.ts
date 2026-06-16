import { clearAllAudio } from "@/lib/audio-storage";
import { clearAllAtmospheres } from "@/lib/atmosphere/atmosphere-storage";
import { clearAllPhotos } from "@/lib/photo-storage";
import { resetOnboarding } from "@/lib/onboarding";
import { clearRecoveryDrafts } from "@/lib/reliability/draft-recovery";
import { clearAllBookmarks } from "@/lib/reflection-bookmarks";
import { clearReminderPreferences } from "@/lib/reminder-preferences";
import { clearReflectionGoal } from "@/lib/reflection-goal";
import { clearProPreview } from "@/lib/subscription";
import { deleteAllEntries } from "@/lib/storage";
import { clearAllWeeklySummaryCache } from "@/lib/weekly-summary-cache";

export async function deleteAllEntriesAndAudio(): Promise<number> {
  const count = await deleteAllEntries();
  await clearAllAudio();
  await clearAllPhotos();
  await clearAllAtmospheres();
  clearAllWeeklySummaryCache();
  return count;
}

export function resetReminderPreferencesToDefault(): void {
  clearReminderPreferences();
}

export function resetOnboardingState(): void {
  resetOnboarding();
}

export function resetProPreviewPlan(): void {
  clearProPreview();
}

export function resetReflectionGoalToDefault(): void {
  clearReflectionGoal();
}

/** Remove all local ArchiveMe data on this device (entries, audio, prefs, drafts). */
export async function runFullLocalReset(): Promise<number> {
  const count = await deleteAllEntriesAndAudio();
  clearAllBookmarks();
  clearRecoveryDrafts();
  resetReminderPreferencesToDefault();
  resetOnboardingState();
  resetReflectionGoalToDefault();
  resetProPreviewPlan();
  return count;
}
