import { clearAllAudio } from "@/lib/audio-storage";
import { resetOnboarding } from "@/lib/onboarding";
import { clearReminderPreferences } from "@/lib/reminder-preferences";
import { clearProPreview } from "@/lib/subscription";
import { deleteAllEntries } from "@/lib/storage";
import { clearAllWeeklySummaryCache } from "@/lib/weekly-summary-cache";

export async function deleteAllEntriesAndAudio(): Promise<number> {
  const count = await deleteAllEntries();
  await clearAllAudio();
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

export async function runFullLocalReset(): Promise<void> {
  await deleteAllEntriesAndAudio();
  resetReminderPreferencesToDefault();
  resetOnboardingState();
  resetProPreviewPlan();
}
