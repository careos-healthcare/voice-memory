import type { ProductDescriptionCategory } from "@/types/archive-as-product-validation";
import type { BlindSpotReaction } from "@/types/blind-spot";
import type { TheoryCuriosityAnswer } from "@/types/personal-theory";

export type FounderTestStudySignal = "strong_signal" | "mixed_signal" | "weak_signal";

/** Q1 — which framing felt more accurate after first review? */
export type FramingAccuracyPreference = "blind_spot" | "working_theory" | "no_difference";

/** Q2 — founder-coded quality of Discover expectation (auto-suggested from verbatim). */
export type DiscoverExpectationQuality = "good" | "weak" | "unclear";

export type FounderValidationVerdict =
  | "insufficient_data"
  | "journal_mode"
  | "evolving_model_signal"
  | "mixed";

export interface FounderTestParticipant {
  id: string;
  label: string;
  startedAt: string;
  completedAt?: string;
  targetReflectionCount: number;
  notes?: string;
}

export interface FounderTestChecklistItem {
  id: string;
  label: string;
  completed: boolean;
  completedAt?: string;
}

export interface FounderTestSession {
  participantId: string;
  reflectionCount: number;
  reachedFiveReflections: boolean;
  openedBlindSpots: boolean;
  openedDiscover: boolean;
  firstBlindSpotReaction?: BlindSpotReaction;
  returnedWithin7Days?: boolean;
  understoodChatGptDifference?: boolean;
  wouldPay?: boolean;
  mainQuote?: string;
  biggestConfusion?: string;
  /** Q1 — blind spot vs working theory framing */
  framingAccuracyPreference?: FramingAccuracyPreference;
  /** Q2 — verbatim: "When you opened Discover, what were you expecting?" */
  discoverExpectationVerbatim?: string;
  discoverExpectationQuality?: DiscoverExpectationQuality;
  /** Q3 — did they wonder if the archive changed its view? */
  theoryCuriosityAnswer?: TheoryCuriosityAnswer;
  /** Q4 — voluntary return ≥24h after first working theory (founder-confirmed) */
  returnedToCheckArchiveView?: boolean;
  /** Archive-as-product — how they describe ArchiveMe (verbatim + code) */
  productDescriptionVerbatim?: string;
  productDescriptionCategory?: ProductDescriptionCategory;
  /** After reflection 5 — first surface on return was Archive (not Discover) */
  openedArchiveBeforeDiscoverPostFive?: boolean;
  /** Reflection 6 felt like archive updated its understanding */
  reflectionSixFeltStronger?: boolean;
  /** Returned on own to check what archive believes (no notification/reminder) */
  voluntaryArchiveReturn?: boolean;
  /** Instant understanding — can they explain ArchiveMe in one sentence? */
  archiveUnderstandingCanExplain?: boolean;
  archiveUnderstandingVerbatim?: string;
  /** Onboarding completion — "What do you think ArchiveMe does?" */
  onboardingProductPerceptionVerbatim?: string;
  onboardingProductPerceptionCategory?: string;
  onboardingProductPerceptionSuccess?: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface FounderDeviceValidationSnapshot {
  theoryCuriosityRate: number | null;
  theoryCuriosityResponses: number;
  returnedToCheckArchiveViewRate: number | null;
  firstWorkingTheorySeenCount: number;
  returnedToCheckCount: number;
}

export interface FounderEvolvingValidationReport {
  mainQuestion: string;
  device: FounderDeviceValidationSnapshot;
  workingTheoryPreferredRate: number | null;
  discoverExpectationGoodRate: number | null;
  interviewTheoryCuriosityRate: number | null;
  interviewReturnedToCheckRate: number | null;
  verdict: FounderValidationVerdict;
  verdictLabel: string;
  lines: string[];
}

export interface FounderTestRecord {
  participant: FounderTestParticipant;
  session: FounderTestSession;
  checklist: FounderTestChecklistItem[];
}

export interface FounderTestRedFlag {
  participantId: string;
  label: string;
  reason: string;
}

export interface FounderTestReport {
  generatedAt: string;
  totalParticipants: number;
  reachedFiveRate: number | null;
  blindSpotOpenRate: number | null;
  discoverOpenRate: number | null;
  surprisingOrAccurateRate: number | null;
  sevenDayReturnRate: number | null;
  chatGptDifferenceUnderstoodRate: number | null;
  wouldPayRate: number | null;
  studySignal: FounderTestStudySignal;
  studySignalLabel: string;
  redFlags: FounderTestRedFlag[];
  strongestQuotes: string[];
  evolvingValidation: FounderEvolvingValidationReport;
  lines: string[];
}
