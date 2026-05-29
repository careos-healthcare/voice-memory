import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { EMOTIONAL_EVAL_DATASET } from "@/lib/emotional-quality/eval-dataset";
import { runCanonicalResurfacingPipeline } from "@/lib/resurfacing/canonical-resurfacing-pipeline";
import { clearUncertaintyBudgetForEval } from "@/lib/resurfacing/uncertainty-budget";
import { isOverconfidentResurfacingCopy } from "@/lib/resurfacing/overconfident-copy";
import { isGenericResurfacing } from "@/lib/resurfacing/genericity-filter";
import {
  clearResurfacingFeedbackForEval,
  getSpecificityThresholdBoost,
  phraseKeyFromQuote,
  recordResurfacingFeedback,
} from "@/lib/resurfacing/resurfacing-feedback";
import { buildResurfacingScores } from "@/lib/resurfacing/resurfacing-scoring";

export interface AplusEmotionalMetrics {
  cases: number;
  precisionProxy: number;
  quoteBackedRate: number;
  genericFalsePositiveRate: number;
  repeatSuppressionRate: number;
  notMePenaltyEffective: boolean;
  tooVagueRaisesThreshold: boolean;
  alreadyKnowFatigueEffective: boolean;
  ambiguityCorrectRate: number;
  whyLinePresentRate: number;
  contradictionNotFlattened: boolean;
  overconfidentBlockedRate: number;
  noEvidenceSuppressedRate: number;
}

const THRESHOLDS = {
  minPrecisionProxy: 0.72,
  maxGenericFalsePositive: 0.15,
  minQuoteBackedRate: 0.55,
  minAmbiguityCorrect: 0.75,
  minWhyLinePresent: 0.85,
  minNoEvidenceSuppressed: 0.9,
};

function resetPhrasePenalty(quote: string): void {
  const key = phraseKeyFromQuote(quote);
  if (!key || typeof localStorage === "undefined") return;
  try {
    const raw = localStorage.getItem("voicememory_resurfacing_feedback");
    if (!raw) return;
    const store = JSON.parse(raw) as { penalties?: Record<string, number> };
    if (store.penalties?.[key]) delete store.penalties[key];
    localStorage.setItem("voicememory_resurfacing_feedback", JSON.stringify(store));
  } catch {
    /* ignore */
  }
}

export function runAplusEmotionalEval(): {
  metrics: AplusEmotionalMetrics;
  failures: string[];
  ok: boolean;
} {
  const failures: string[] = [];
  let correct = 0;
  let quoteBackedShown = 0;
  let shown = 0;
  let genericFalsePositives = 0;
  let genericCases = 0;
  let repeatBlocked = 0;
  let notMeOk = true;
  let tooVagueOk = true;
  let alreadyKnowOk = true;
  let ambiguityCases = 0;
  let ambiguityCorrect = 0;
  let whyPresent = 0;
  let whyTotal = 0;
  let contradictionOk = true;
  let overconfidentBlocked = 0;
  let overconfidentCases = 0;
  let noEvidenceSuppressed = 0;
  let noEvidenceCases = 0;

  clearUncertaintyBudgetForEval();

  for (const case_ of EMOTIONAL_EVAL_DATASET) {
    clearUncertaintyBudgetForEval();
    clearResurfacingFeedbackForEval();
    if (case_.priorFeedback) {
      recordResurfacingFeedback({
        kind: case_.priorFeedback,
        quote: case_.quote,
        surface: "first_return",
      });
    }

    const scores = buildResurfacingScores({
      quote: case_.quote,
      appearances: case_.appearances,
      gapDays: case_.gapDays,
      threadType: case_.threadType,
    });

    const pipeline = runCanonicalResurfacingPipeline({
      quote: case_.quote,
      appearances: case_.appearances,
      gapDays: case_.gapDays,
      threadType: case_.threadType,
      pastQuote: case_.pastQuote,
      currentQuote: case_.currentQuote,
      missingTranscript: case_.quote.trim().length === 0,
    });

    const show = pipeline.show;
    const why = pipeline.whySurfacedLines[0] ?? "";

    if (show === case_.expectShow) correct += 1;
    else {
      failures.push(
        `${case_.id}: expected show=${case_.expectShow} got ${show} (conf=${pipeline.finalConfidence})`,
      );
    }

    if (case_.expectGeneric) {
      genericCases += 1;
      if (show) genericFalsePositives += 1;
    }

    if (!case_.expectShow) {
      noEvidenceCases += 1;
      if (!show) noEvidenceSuppressed += 1;
    }

    if (show) {
      shown += 1;
      if (case_.expectQuoteBacked && scores.quoteMatchScore >= 50) {
        quoteBackedShown += 1;
      }
      if (isOverconfidentResurfacingCopy(why) || isOverconfidentResurfacingCopy(case_.quote)) {
        failures.push(`${case_.id}: overconfident wording on shown callback`);
      }
    }

    if (case_.id === "not-me-penalized" && show) notMeOk = false;
    if (case_.id === "too-vague-feedback") {
      const boost = getSpecificityThresholdBoost();
      if (boost < 6 || show) tooVagueOk = false;
    } else if (case_.priorFeedback === "too_vague" && show) {
      tooVagueOk = false;
    }
    if (case_.id === "already-know-fatigue" && show) alreadyKnowOk = false;
    if (case_.id === "repeated-stale-callback" && show) alreadyKnowOk = false;

    if (case_.appearances >= 2 && !show && !case_.expectShow) repeatBlocked += 1;

    if (case_.expectAmbiguity || pipeline.safeDisplayMode === "cautious") {
      ambiguityCases += 1;
      if (
        why.toLowerCase().includes("might") ||
        why.toLowerCase().includes("may") ||
        why.toLowerCase().includes("loose")
      ) {
        ambiguityCorrect += 1;
      }
    }

    if (case_.expectContradiction && show) {
      const changeOk =
        pipeline.safeDisplayMode === "change" ||
        Boolean(pipeline.evidence.contradictionSignal) ||
        Boolean(pipeline.evidence.emotionalShift);
      if (!changeOk) {
        contradictionOk = false;
        failures.push(`${case_.id}: contradiction flattened in why line`);
      }
    }

    if (case_.expectOverconfidentBlocked) {
      overconfidentCases += 1;
      if (!show) overconfidentBlocked += 1;
    }

    if (show || case_.expectShow) {
      whyTotal += 1;
      if (why.length > 10) whyPresent += 1;
    }

    if (case_.expectGeneric && isGenericResurfacing(case_.quote) && show) {
      failures.push(`${case_.id}: generic resurfacing passed gate`);
    }
  }

  const metrics: AplusEmotionalMetrics = {
    cases: EMOTIONAL_EVAL_DATASET.length,
    precisionProxy: correct / EMOTIONAL_EVAL_DATASET.length,
    quoteBackedRate: shown > 0 ? quoteBackedShown / shown : 0,
    genericFalsePositiveRate:
      genericCases > 0 ? genericFalsePositives / genericCases : 0,
    repeatSuppressionRate: repeatBlocked / EMOTIONAL_EVAL_DATASET.length,
    notMePenaltyEffective: notMeOk,
    tooVagueRaisesThreshold: tooVagueOk,
    alreadyKnowFatigueEffective: alreadyKnowOk,
    ambiguityCorrectRate:
      ambiguityCases > 0 ? ambiguityCorrect / ambiguityCases : 1,
    whyLinePresentRate: whyTotal > 0 ? whyPresent / whyTotal : 1,
    contradictionNotFlattened: contradictionOk,
    overconfidentBlockedRate:
      overconfidentCases > 0 ? overconfidentBlocked / overconfidentCases : 1,
    noEvidenceSuppressedRate:
      noEvidenceCases > 0 ? noEvidenceSuppressed / noEvidenceCases : 1,
  };

  if (metrics.precisionProxy < THRESHOLDS.minPrecisionProxy) {
    failures.push(
      `precision ${metrics.precisionProxy.toFixed(2)} < ${THRESHOLDS.minPrecisionProxy}`,
    );
  }
  if (metrics.genericFalsePositiveRate > THRESHOLDS.maxGenericFalsePositive) {
    failures.push(
      `generic FP ${metrics.genericFalsePositiveRate.toFixed(2)} > ${THRESHOLDS.maxGenericFalsePositive}`,
    );
  }
  if (shown > 0 && metrics.quoteBackedRate < THRESHOLDS.minQuoteBackedRate) {
    failures.push(
      `quote-backed ${metrics.quoteBackedRate.toFixed(2)} < ${THRESHOLDS.minQuoteBackedRate}`,
    );
  }
  if (!metrics.notMePenaltyEffective) failures.push("not-me penalty failed");
  if (!metrics.tooVagueRaisesThreshold) failures.push("too-vague threshold failed");
  if (!metrics.alreadyKnowFatigueEffective) {
    failures.push("already-know fatigue failed");
  }
  if (!metrics.contradictionNotFlattened) {
    failures.push("contradiction flattened");
  }
  if (metrics.ambiguityCorrectRate < THRESHOLDS.minAmbiguityCorrect) {
    failures.push("ambiguity phrasing below threshold");
  }
  if (metrics.whyLinePresentRate < THRESHOLDS.minWhyLinePresent) {
    failures.push("why-surfaced line missing on expected cases");
  }
  if (metrics.noEvidenceSuppressedRate < THRESHOLDS.minNoEvidenceSuppressed) {
    failures.push("no-evidence cases not suppressed enough");
  }

  return { metrics, failures, ok: failures.length === 0 };
}

export function defaultAplusEmotionalReportPath(): string {
  if (process.env.EMOTIONAL_APLUS_REPORT_PATH) {
    return process.env.EMOTIONAL_APLUS_REPORT_PATH;
  }
  return resolve(
    process.env.HOME ?? "/Users/chiragpatel",
    "Desktop/spp20/emotional_ai_aplus_eval_report.md",
  );
}

export function writeAplusEmotionalReport(
  result: ReturnType<typeof runAplusEmotionalEval>,
  reportPath = defaultAplusEmotionalReportPath(),
): void {
  const lines = [
    "# Emotional AI A+ Eval Report (Proxy)",
    "",
    `**Generated:** ${new Date().toISOString()}`,
    "",
    "> Field validation after launch is still required. This is a seeded adversarial proxy only.",
    "",
    "## Metrics",
    "",
    "| Metric | Value |",
    "|--------|-------|",
    ...Object.entries(result.metrics).map(([k, v]) => `| ${k} | ${v} |`),
    "",
    `**Status:** ${result.ok ? "PASS" : "FAIL"}`,
    "",
    "**Honest grade:** Code-proven resurfacing restraint proxy — not field emotional AI proof.",
    "",
  ];
  if (result.failures.length) {
    lines.push("## Failures", "", ...result.failures.map((f) => `- ${f}`));
  }
  const inRepo = resolve(
    process.cwd(),
    "docs/reports/emotional_ai_aplus_eval_report.md",
  );
  const targets = [reportPath, inRepo].filter(
    (p, i, arr) => arr.indexOf(p) === i,
  );
  for (const target of targets) {
    try {
      mkdirSync(dirname(target), { recursive: true });
      writeFileSync(target, lines.join("\n"));
    } catch {
      /* try next path */
    }
  }
}
