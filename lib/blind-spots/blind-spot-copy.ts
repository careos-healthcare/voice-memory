import { EVIDENCE_FOR_BELIEF_EYEBROW, EVIDENCE_FOR_BELIEF_LEAD } from "@/lib/archive/archive-belief-centric-copy";
import type { EvidenceStrengthLabel } from "@/types/blind-spot";

export const BLIND_SPOT_MIN_REFLECTIONS = 5;

export const BLIND_SPOT_EMPTY_MESSAGE =
  "Not enough history yet. Blind spots need repeated evidence.";

export const BLIND_SPOT_WEAK_EVIDENCE_MESSAGE =
  "I found repeated themes, but not enough evidence for a serious blind spot yet.";

export const EVIDENCE_STRENGTH_LABELS: Record<EvidenceStrengthLabel, string> = {
  low: "Low",
  medium: "Medium",
  high: "High",
  very_high: "Very High",
};

export const BLIND_SPOT_FIRST_REVIEW = {
  notVerdict:
    "This is not a verdict. It is the first theory your archive can support.",
  mayChange:
    "As you add more moments, this may strengthen, weaken, or disappear.",
  archiveView:
    "ArchiveMe is starting to build an evidence-based view of what keeps repeating.",
} as const;

export const BLIND_SPOT_PAGE = {
  eyebrow: EVIDENCE_FOR_BELIEF_EYEBROW,
  title: "Evidence for belief",
  lead: EVIDENCE_FOR_BELIEF_LEAD,
  mostExpensiveBelief: "First working theory",
  sinceLastTimeTitle: "What changed since last time",
  sinceLastTimeNoChange:
    "No major change yet. More moments may make this clearer.",
  sinceLastTimeLead:
    "ArchiveMe may be refining its read of you — early signals only, not conclusions.",
  disclaimer:
    "Evidence from your archive only. This may be wrong. Not therapy, not a diagnosis, not certainty.",
  evidenceLead: "Your words suggest this showed up more than once:",
  evidenceStrengthTitle: "Evidence strength",
  whyThisMattersTitle: "Why this matters",
  likelyCostTitle: "What this pattern may be costing",
  ifSoftenedTitle: "If this pattern softened",
  alternativeTitle: "Alternative to try next time",
  experimentTitle: "One small experiment to try",
  experimentSmallThing: "One small thing to try",
  experimentTryNextTime: "Try this next time",
  experimentCheckWhether: "Check whether this changes anything",
  experimentDisclaimer:
    "Not advice. Just something to compare against your own history.",
  experimentFeedbackPrompt: "Did this experiment land?",
  experimentReactionLabels: {
    will_try: "I'll try this",
    not_useful: "Not useful",
    already_tried: "Already tried",
  } as const,
  experimentFollowUpQuestion: "Did you notice this pattern again?",
  experimentFollowUpLabels: {
    caught_earlier: "Yes, I caught it earlier",
    after_the_fact: "Yes, but after the fact",
    no: "No",
    not_sure: "Not sure",
  } as const,
  experimentFollowUpHelper:
    "Seven-day check — helps ArchiveMe learn whether the experiment changed anything.",
  experimentCommitmentSaved:
    "Saved — we'll check in about a week. Not advice, just a check against your history.",
  feedbackPrompt: "How did this land?",
  feedbackHelper:
    "We are trying to learn whether this theory felt genuinely new or meaningful.",
  reactionLabels: {
    obvious: "Obvious",
    interesting: "Interesting",
    surprising: "Surprising",
    uncomfortably_accurate: "Uncomfortably Accurate",
    completely_wrong: "Completely Wrong",
  } as const,
  ctaTitle: "Blind spot discovery",
  ctaBody:
    "See your most expensive belief — ranked by impact, with dated quotes from your thinking history.",
  ctaAction: "Review blind spots",
  emergingTitle: "Possible emerging patterns",
  emergingDisclaimer: "Hypotheses only — not conclusions. Low confidence until more evidence builds.",
  costEvidenceTitle: "What may have followed",
  costEvidenceLead: "Counts from moments after this pattern — may suggest cost, not proof.",
  predictionTitle: "Predictions vs reality",
  predictionLead:
    "Where your expectations and later moments may have diverged — not a score about you.",
  predictionQuoteLabel: "Prediction",
  predictionLaterLabel: "Later evidence",
  observationTitle: "Observation",
  possiblePatternTitle: "Working theory",
  whyMayMatterTitle: "Why it may matter",
  breakthroughPrompt: "What part felt most true?",
  breakthroughHelper: "Optional — helps us learn what you actually value in a breakthrough moment.",
  delayedValidationPrompt:
    "Looking back, does this insight feel any different now?",
  delayedChangedMind: "Changed my mind",
  delayedStillWrong: "Still wrong",
  delayedNowAccurate: "Now feels accurate",
} as const;
