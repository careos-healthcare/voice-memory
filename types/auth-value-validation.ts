import type { AuthTriggerReason } from "@/types/auth-trigger";

export type AuthValueVerdict = "strong" | "weak" | "mixed" | "insufficient_data";

export interface AuthValueFunnelRow {
  reason: AuthTriggerReason | "all";
  promptsShown: number;
  verified: number;
  conversionRate: number | null;
}

export interface AuthValueValidationReport {
  mainQuestion: string;
  verdict: AuthValueVerdict;
  verdictAnswer: string;
  guestModeStarted: number;
  protectArchiveBannerSeen: number;
  protectArchiveClicked: number;
  protectArchiveConversionRate: number | null;
  firstWorkingBeliefPromptRate: number | null;
  paywallPromptToVerifiedRate: number | null;
  authPromptsShown: number;
  authVerified: number;
  overallPromptToVerifiedRate: number | null;
  funnelByReason: AuthValueFunnelRow[];
  lines: string[];
  pausedBuilds: string[];
}
