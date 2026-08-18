import { readFounderTestRecords, updateFounderTestSession } from "@/lib/founder-test/founder-test-storage";

export const ONBOARDING_CONFIDENCE_PROMPT =
  "What do you think ArchiveMe does?";

export const ONBOARDING_CONFIDENCE_STORAGE_KEY =
  "voicememory_onboarding_product_perception";

export type OnboardingProductPerceptionCategory =
  | "tracks_archive_belief"
  | "journal"
  | "ai_coach"
  | "notes_app"
  | "therapy_app"
  | "unclear";

export type OnboardingConfidenceResult = {
  verbatim: string;
  category: OnboardingProductPerceptionCategory;
  success: boolean;
};

export function classifyOnboardingProductPerception(
  verbatim: string,
): OnboardingProductPerceptionCategory {
  const t = verbatim.trim().toLowerCase();
  if (!t) return "unclear";

  if (
    /\b(tracks?|tracks what|what my archive believes|archive believes|believes about me|evolving archive|belief history)\b/i.test(
      t,
    )
  ) {
    return "tracks_archive_belief";
  }
  if (/\b(therapy|therapist|mental health app|counseling)\b/i.test(t)) {
    return "therapy_app";
  }
  if (/\b(ai coach|coaching app|life coach|chatgpt|assistant)\b/i.test(t)) {
    return "ai_coach";
  }
  if (/\b(notes app|note.?taking|voice notes|notepad)\b/i.test(t)) {
    return "notes_app";
  }
  if (/\b(journal|diary|logging thoughts|reflection app)\b/i.test(t)) {
    return "journal";
  }
  return "unclear";
}

export function buildOnboardingConfidenceResult(
  verbatim: string,
): OnboardingConfidenceResult {
  const category = classifyOnboardingProductPerception(verbatim);
  return {
    verbatim: verbatim.trim(),
    category,
    success: category === "tracks_archive_belief",
  };
}

export function persistOnboardingConfidenceResult(result: OnboardingConfidenceResult): void {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(
      ONBOARDING_CONFIDENCE_STORAGE_KEY,
      JSON.stringify({ ...result, recordedAt: new Date().toISOString() }),
    );
  } catch {
    /* ignore quota */
  }

  const records = readFounderTestRecords();
  const active = records[records.length - 1];
  if (!active) return;
  updateFounderTestSession(active.participant.id, {
    onboardingProductPerceptionVerbatim: result.verbatim,
    onboardingProductPerceptionCategory: result.category,
    onboardingProductPerceptionSuccess: result.success,
  });
}

export function readOnboardingConfidenceResult(): OnboardingConfidenceResult | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = localStorage.getItem(ONBOARDING_CONFIDENCE_STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as OnboardingConfidenceResult;
    if (!parsed?.verbatim || !parsed?.category) return null;
    return parsed;
  } catch {
    return null;
  }
}
