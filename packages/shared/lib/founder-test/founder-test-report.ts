import { buildFounderEvolvingValidationReport } from "@/lib/founder-test/founder-evolving-validation";
import {
  classifyFounderTestStudySignal,
  FOUNDER_TEST_STUDY_SIGNAL_LABELS,
} from "@/lib/founder-test/founder-test-thresholds";
import { readFounderTestRecords } from "@/lib/founder-test/founder-test-storage";
import type {
  FounderTestRecord,
  FounderTestRedFlag,
  FounderTestReport,
} from "@/types/founder-test";

const STRONG_REACTIONS = new Set(["surprising", "uncomfortably_accurate"]);
const CHATGPT_CONFUSION_RE =
  /\b(why not chatgpt|why chatgpt|just use chatgpt|same as chatgpt|notes app|google doc)\b/i;

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function rateForBoolean(
  records: FounderTestRecord[],
  pick: (session: FounderTestRecord["session"]) => boolean | undefined,
): number | null {
  const answered = records.filter((r) => pick(r.session) !== undefined);
  if (answered.length === 0) return null;
  const yes = answered.filter((r) => pick(r.session) === true).length;
  return pct(yes, answered.length);
}

function buildRedFlags(records: FounderTestRecord[]): FounderTestRedFlag[] {
  const flags: FounderTestRedFlag[] = [];

  for (const { participant, session } of records) {
    if (
      session.reachedFiveReflections &&
      (!session.firstBlindSpotReaction || !STRONG_REACTIONS.has(session.firstBlindSpotReaction))
    ) {
      flags.push({
        participantId: participant.id,
        label: participant.label,
        reason: "Reached 5 reflections but no Surprising or Uncomfortably Accurate reaction",
      });
    }

    const confusion = `${session.biggestConfusion ?? ""} ${participant.notes ?? ""}`;
    if (CHATGPT_CONFUSION_RE.test(confusion)) {
      flags.push({
        participantId: participant.id,
        label: participant.label,
        reason: 'Asked "why not ChatGPT?" or similar confusion',
      });
    }

    if (session.returnedWithin7Days === false) {
      flags.push({
        participantId: participant.id,
        label: participant.label,
        reason: "Did not return within 7 days",
      });
    }

    if (session.wouldPay === false) {
      flags.push({
        participantId: participant.id,
        label: participant.label,
        reason: "Would not pay",
      });
    }

    if (session.firstBlindSpotReaction === "obvious") {
      flags.push({
        participantId: participant.id,
        label: participant.label,
        reason: "Found first blind spot insight obvious",
      });
    }
  }

  return flags;
}

export function buildFounderTestReport(
  records = readFounderTestRecords(),
): FounderTestReport {
  const total = records.length;

  const reachedFiveRate = pct(
    records.filter((r) => r.session.reachedFiveReflections).length,
    total,
  );
  const blindSpotOpenRate = pct(
    records.filter((r) => r.session.openedBlindSpots).length,
    total,
  );
  const discoverOpenRate = pct(records.filter((r) => r.session.openedDiscover).length, total);

  const withReaction = records.filter((r) => r.session.firstBlindSpotReaction);
  const surprisingOrAccurateRate = pct(
    withReaction.filter((r) =>
      STRONG_REACTIONS.has(r.session.firstBlindSpotReaction!),
    ).length,
    withReaction.length > 0 ? withReaction.length : total,
  );

  const sevenDayReturnRate = rateForBoolean(records, (s) => s.returnedWithin7Days);
  const chatGptDifferenceUnderstoodRate = rateForBoolean(
    records,
    (s) => s.understoodChatGptDifference,
  );
  const wouldPayRate = rateForBoolean(records, (s) => s.wouldPay);

  const redFlags = buildRedFlags(records);
  const strongestQuotes = records
    .map((r) => r.session.mainQuote?.trim())
    .filter((q): q is string => Boolean(q && q.length > 2))
    .slice(0, 8);

  const partial: Omit<
    FounderTestReport,
    "studySignal" | "studySignalLabel" | "lines" | "generatedAt" | "evolvingValidation"
  > =
    {
      totalParticipants: total,
      reachedFiveRate,
      blindSpotOpenRate,
      discoverOpenRate,
      surprisingOrAccurateRate,
      sevenDayReturnRate,
      chatGptDifferenceUnderstoodRate,
      wouldPayRate,
      redFlags,
      strongestQuotes,
    };

  const studySignal = classifyFounderTestStudySignal({
    totalParticipants: total,
    reachedFiveRate,
    surprisingOrAccurateRate,
    sevenDayReturnRate,
    chatGptDifferenceUnderstoodRate,
    wouldPayRate,
  });

  const evolvingValidation = buildFounderEvolvingValidationReport(records);

  const lines = [
    `Participants: ${total}`,
    `5-reflection conversion: ${reachedFiveRate ?? "—"}%`,
    `Blind spot open rate: ${blindSpotOpenRate ?? "—"}%`,
    `Discover open rate: ${discoverOpenRate ?? "—"}%`,
    `Surprising / uncomfortably accurate: ${surprisingOrAccurateRate ?? "—"}%`,
    `7-day return: ${sevenDayReturnRate ?? "—"}%`,
    `ChatGPT difference understood: ${chatGptDifferenceUnderstoodRate ?? "—"}%`,
    `Would pay: ${wouldPayRate ?? "—"}%`,
    `Red flags: ${redFlags.length}`,
    ...evolvingValidation.lines.map((line) => `Validation: ${line}`),
  ];

  return {
    generatedAt: new Date().toISOString(),
    ...partial,
    studySignal,
    studySignalLabel: FOUNDER_TEST_STUDY_SIGNAL_LABELS[studySignal],
    evolvingValidation,
    lines,
  };
}
