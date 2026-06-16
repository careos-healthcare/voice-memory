import { readFounderTestRecords } from "@/lib/founder-test/founder-test-storage";
import { buildEvolvingUnderstandingReport } from "@/lib/metrics/evolving-understanding-report";
import { isCuriousAnswer } from "@/lib/metrics/theory-curiosity-engine";
import { buildTheoryCuriosityReport } from "@/lib/metrics/theory-curiosity";
import type {
  DiscoverExpectationQuality,
  FounderDeviceValidationSnapshot,
  FounderEvolvingValidationReport,
  FounderTestRecord,
  FounderValidationVerdict,
} from "@/types/founder-test";

export const FOUNDER_VALIDATION_PHASE = {
  paused: "Product development pauses. Behavioral validation begins.",
  oldGoal: "Can ArchiveMe generate insights?",
  newGoal: "Do users start treating ArchiveMe like an evolving model of themselves?",
  ifNo: "Fix the loop.",
  ifYes: "Double down on it.",
} as const;

/** Run 10–20 founder interviews before another major feature. */
export const FOUNDER_VALIDATION_INTERVIEW_TARGET = { min: 10, max: 20, label: "10–20" } as const;

export const FOUNDER_TWO_WEEK_SUCCESS_CRITERIA = [
  "Users prefer Working theory over Blind spot",
  "Users expect Discover to show belief changes",
  "Theory Curiosity Rate increases",
  "Returned to Check Archive View Rate increases",
] as const;

export const FOUNDER_VALIDATION_NOT_WATCHING = [
  "Page views",
  "Clicks",
  "Notification opens",
  "Dashboard metrics",
] as const;

export const FOUNDER_VALIDATION_PRIMARY_BEHAVIOR =
  "Did someone voluntarily come back because they thought the archive might have changed its view of them?";

export const FOUNDER_ROADMAP_GATE = {
  buildTheoryAccuracyHistory:
    'Interviews say: “I wanted to see if ArchiveMe had changed its mind.” → build Theory Accuracy History next.',
  fixLoopNotHistory:
    'Interviews say: “I was just looking for another insight.” → mental model not shifted; fix the loop, do not build History yet.',
} as const;

export const FOUNDER_CATEGORY_POSITIONING =
  "ArchiveMe doesn't try to explain you from one reflection. It builds and revises theories as evidence accumulates.";

export const FOUNDER_MENTAL_MODEL_DISTINCTION = {
  success: "ArchiveMe is building a case about me.",
  failure: "ArchiveMe occasionally gives me insights.",
} as const;

export const FOUNDER_EVOLVING_VALIDATION_MAIN_QUESTION =
  "Did the mental model shift from “ArchiveMe gave me an answer” to “ArchiveMe is building a case” — and did behaviour follow?";

/** If 3 and 4 don’t move, new framing isn’t changing behavior. */
export const FOUNDER_VALIDATION_BEHAVIOR_GATE =
  "If Theory Curiosity Rate and Returned to Check Archive View Rate don’t move, framing isn’t changing behavior.";

export const FOUNDER_EVOLVING_VALIDATION_QUESTIONS = {
  framingAccuracy: {
    id: "framing_accuracy",
    prompt: "Which felt more accurate?",
    options: [
      { value: "blind_spot" as const, label: "Blind spot" },
      { value: "working_theory" as const, label: "Working theory" },
      { value: "no_difference" as const, label: "No difference" },
    ],
    passSignal: "Majority prefer Working theory — framing is correct.",
  },
  discoverExpectation: {
    id: "discover_expectation",
    prompt: "When you opened Discover, what were you expecting to see?",
    goodExamples: [
      "whether confidence changed",
      "whether the archive changed its mind",
      "whether theories strengthened or weakened",
    ],
    weakExamples: [
      "nothing",
      "just checking",
      "another insight",
      "curiosity absent",
    ],
  },
  theoryCuriosity: {
    id: "theory_curiosity",
    prompt:
      "Before opening ArchiveMe, were you curious whether it had changed its view of you?",
    passSignal:
      "Rising Theory Curiosity Rate (yes/maybe) — archive seen as an evolving model, not a journal.",
  },
  returnedToCheck: {
    id: "returned_to_check",
    prompt:
      "Did they voluntarily return to Discover or Theories ≥24h after their first working theory?",
    passSignal:
      "Rising Returned to Check Archive View Rate — strongest retention leading indicator.",
  },
} as const;

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

/** Suggest good / weak / unclear from interview verbatim (founder can override). */
export function classifyDiscoverExpectationVerbatim(
  verbatim: string,
): DiscoverExpectationQuality {
  const t = verbatim.trim().toLowerCase();
  if (!t) return "unclear";

  const good =
    /\b(confidence|changed its mind|changed my mind|changed the mind|strengthen|weaken|theor|archive|contradict|evidence|believe|shift|update|different|revis)\b/i;
  const weak =
    /\b(nothing|just check|just looking|another insight|new insight|more insight|next insight|habit|not sure|don't know|didn't know|idk|no idea|bored|random)\b/i;

  if (weak.test(t) && !good.test(t)) return "weak";
  if (good.test(t)) return "good";
  return "unclear";
}

export function readFounderDeviceValidationSnapshot(): FounderDeviceValidationSnapshot {
  const curiosity = buildTheoryCuriosityReport();
  const evolving = buildEvolvingUnderstandingReport();

  return {
    theoryCuriosityRate:
      curiosity.totalResponses > 0 ? curiosity.theoryCuriosityRate : null,
    theoryCuriosityResponses: curiosity.totalResponses,
    returnedToCheckArchiveViewRate: evolving.returnedToCheckArchiveViewRate,
    firstWorkingTheorySeenCount: evolving.firstBlindSpotSeenCount,
    returnedToCheckCount: evolving.returnedToCheckArchiveViewCount,
  };
}

function rateFramingPreference(records: FounderTestRecord[] | undefined): number | null {
  if (!records?.length) return null;
  const answered = records.filter((r) => r.session.framingAccuracyPreference);
  if (answered.length === 0) return null;
  const preferWorking = answered.filter(
    (r) => r.session.framingAccuracyPreference === "working_theory",
  ).length;
  return pct(preferWorking, answered.length);
}

function rateDiscoverGood(records: FounderTestRecord[] | undefined): number | null {
  if (!records?.length) return null;
  const answered = records.filter((r) => r.session.discoverExpectationQuality);
  if (answered.length === 0) return null;
  const good = answered.filter((r) => r.session.discoverExpectationQuality === "good").length;
  return pct(good, answered.length);
}

function rateInterviewCuriosity(records: FounderTestRecord[] | undefined): number | null {
  if (!records?.length) return null;
  const answered = records.filter((r) => r.session.theoryCuriosityAnswer);
  if (answered.length === 0) return null;
  const curious = answered.filter((r) =>
    isCuriousAnswer(r.session.theoryCuriosityAnswer!),
  ).length;
  return pct(curious, answered.length);
}

function rateInterviewReturned(records: FounderTestRecord[] | undefined): number | null {
  return rateForBoolean(records, (s) => s.returnedToCheckArchiveView);
}

function rateForBoolean(
  records: FounderTestRecord[] | undefined,
  pick: (session: FounderTestRecord["session"]) => boolean | undefined,
): number | null {
  if (!records?.length) return null;
  const answered = records.filter((r) => pick(r.session) !== undefined);
  if (answered.length === 0) return null;
  const yes = answered.filter((r) => pick(r.session) === true).length;
  return pct(yes, answered.length);
}

const VERDICT_LABELS: Record<FounderValidationVerdict, string> = {
  insufficient_data: `Not enough interviews yet — run ${FOUNDER_VALIDATION_INTERVIEW_TARGET.label} founder interviews after first working theory.`,
  journal_mode:
    "Still journal mode — low curiosity and weak Discover expectations; framing may not be landing.",
  evolving_model_signal:
    "Evolving-model signal — curiosity and/or voluntary return to check the archive view.",
  mixed: "Mixed — some signals up, some down; keep interviewing before building Theory Accuracy History.",
};

function classifyValidationVerdict(input: {
  participantCount: number;
  framingAnswered: number;
  workingTheoryPreferredRate: number | null;
  discoverGoodRate: number | null;
  interviewCuriosityRate: number | null;
  interviewReturnedRate: number | null;
  deviceCuriosityRate: number | null;
  deviceReturnedRate: number | null;
}): FounderValidationVerdict {
  const {
    participantCount,
    framingAnswered,
    workingTheoryPreferredRate,
    discoverGoodRate,
    interviewCuriosityRate,
    interviewReturnedRate,
    deviceCuriosityRate,
    deviceReturnedRate,
  } = input;

  if (participantCount < 3 || framingAnswered < 2) {
    return "insufficient_data";
  }

  const curiosity =
    interviewCuriosityRate ?? deviceCuriosityRate ?? null;
  const returned = interviewReturnedRate ?? deviceReturnedRate ?? null;
  const discoverGood = discoverGoodRate ?? null;
  const framingWin =
    workingTheoryPreferredRate !== null && workingTheoryPreferredRate >= 50;

  const evolvingSignals = [
    returned !== null && returned >= 35,
    curiosity !== null && curiosity >= 45,
    discoverGood !== null && discoverGood >= 50,
    framingWin,
  ].filter(Boolean).length;

  const journalSignals = [
    returned !== null && returned < 20,
    curiosity !== null && curiosity < 25,
    discoverGood !== null && discoverGood < 30,
  ].filter(Boolean).length;

  if (evolvingSignals >= 2 && journalSignals === 0) return "evolving_model_signal";
  if (journalSignals >= 2 && evolvingSignals === 0) return "journal_mode";
  if (evolvingSignals >= 1 || journalSignals >= 1) return "mixed";
  return "insufficient_data";
}

export function buildFounderEvolvingValidationReport(
  records?: FounderTestRecord[],
): FounderEvolvingValidationReport {
  const list = (Array.isArray(records) ? records : readFounderTestRecords()) ?? [];
  const device = readFounderDeviceValidationSnapshot();
  const workingTheoryPreferredRate = rateFramingPreference(list);
  const discoverExpectationGoodRate = rateDiscoverGood(list);
  const interviewTheoryCuriosityRate = rateInterviewCuriosity(list);
  const interviewReturnedToCheckRate = rateInterviewReturned(list);

  const framingAnswered = list.filter((r) => r.session.framingAccuracyPreference).length;

  const verdict = classifyValidationVerdict({
    participantCount: list.length,
    framingAnswered,
    workingTheoryPreferredRate,
    discoverGoodRate: discoverExpectationGoodRate,
    interviewCuriosityRate: interviewTheoryCuriosityRate,
    interviewReturnedRate: interviewReturnedToCheckRate,
    deviceCuriosityRate: device.theoryCuriosityRate,
    deviceReturnedRate: device.returnedToCheckArchiveViewRate,
  });

  const lines = [
    `Q1 Working theory preferred: ${workingTheoryPreferredRate ?? "—"}% (n=${framingAnswered})`,
    `Q2 Discover “good” expectation: ${discoverExpectationGoodRate ?? "—"}%`,
    `Q3 Interview curiosity (yes/maybe): ${interviewTheoryCuriosityRate ?? "—"}%`,
    `Q3 Device Theory Curiosity Rate: ${device.theoryCuriosityRate ?? "—"}% (${device.theoryCuriosityResponses} prompts)`,
    `Q4 Interview returned to check archive: ${interviewReturnedToCheckRate ?? "—"}%`,
    `Q4 Device Returned to Check Archive View Rate: ${device.returnedToCheckArchiveViewRate ?? "—"}% (${device.returnedToCheckCount}/${device.firstWorkingTheorySeenCount} first theories)`,
  ];

  return {
    mainQuestion: FOUNDER_EVOLVING_VALIDATION_MAIN_QUESTION,
    device,
    workingTheoryPreferredRate,
    discoverExpectationGoodRate,
    interviewTheoryCuriosityRate,
    interviewReturnedToCheckRate,
    verdict,
    verdictLabel: VERDICT_LABELS[verdict],
    lines,
  };
}
