import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { EMOTIONAL_EVAL_DATASET } from "@/lib/emotional-quality/eval-dataset";
import { runAplusEmotionalEval } from "@/lib/emotional-quality/run-aplus-eval";
import { runCanonicalPipelineForContinuity } from "@/lib/resurfacing/canonical-resurfacing-pipeline";
import { isOverconfidentResurfacingCopy } from "@/lib/resurfacing/overconfident-copy";
import {
  getSpecificityThresholdBoost,
  recordResurfacingFeedback,
  userFeedbackPenaltyForPhrase,
  phraseKeyFromQuote,
} from "@/lib/resurfacing/resurfacing-feedback";

const STRICT_FAIL_IDS = new Set([
  "sarcasm-lol",
  "sarcasm-totally-fine",
  "vague-memory",
  "vague-this-thing",
  "flat-note",
  "pronoun-only-he",
  "generic-should-hide",
  "not-me-penalized",
  "already-know-fatigue",
  "repeated-stale-callback",
  "overconfident-if-shown",
  "missing-transcript-empty",
]);

export function runAdversarialEmotionalEval(): {
  ok: boolean;
  failures: string[];
  strictFails: string[];
} {
  const base = runAplusEmotionalEval();
  const failures = [...base.failures];
  const strictFails: string[] = [];

  for (const case_ of EMOTIONAL_EVAL_DATASET) {
    if (!STRICT_FAIL_IDS.has(case_.id)) continue;

    if (case_.priorFeedback) {
      recordResurfacingFeedback({
        kind: case_.priorFeedback,
        quote: case_.quote,
        surface: "first_return",
      });
    }

    const gate = runCanonicalPipelineForContinuity({
      quote: case_.quote,
      appearances: case_.appearances,
      gapDays: case_.gapDays,
      threadType: case_.threadType,
    });

    if (gate.show && !case_.expectShow) {
      strictFails.push(`${case_.id}: strict adversarial case surfaced`);
    }

    if (case_.expectAmbiguity && gate.show) {
      const why = (gate.whySurfacedLines[0] ?? "").toLowerCase();
      if (
        !why.includes("might") &&
        !why.includes("may") &&
        !why.includes("loose")
      ) {
        strictFails.push(`${case_.id}: ambiguous case missing cautious why line`);
      }
      if (isOverconfidentResurfacingCopy(gate.whySurfacedLines[0] ?? "")) {
        strictFails.push(`${case_.id}: overconfident wording on ambiguous case`);
      }
    }
  }

  recordResurfacingFeedback({
    kind: "too_vague",
    quote: '"test specificity threshold"',
    surface: "callback",
  });
  const boost = getSpecificityThresholdBoost();
  if (boost < 6) {
    failures.push("too_vague did not raise specificity threshold");
  }

  recordResurfacingFeedback({
    kind: "not_me",
    quote: '"test not me cluster"',
    surface: "callback",
  });
  const key = phraseKeyFromQuote('"test not me cluster"');
  if (userFeedbackPenaltyForPhrase(key) < 35) {
    failures.push("not_me did not apply suppression penalty");
  }

  recordResurfacingFeedback({
    kind: "already_know",
    quote: '"test already know fatigue"',
    surface: "callback",
  });
  const akGate = runCanonicalPipelineForContinuity({
    quote: '"test already know fatigue"',
    appearances: 4,
    gapDays: 10,
  });
  if (akGate.show && akGate.evidence.priorUserRejection < 20) {
    failures.push("already_know did not increase rejection weight");
  }

  const ok = failures.length === 0 && strictFails.length === 0;
  return { ok, failures, strictFails };
}

export function defaultAdversarialReportPath(): string {
  return resolve(
    process.env.HOME ?? "/Users/chiragpatel",
    "Desktop/spp20/emotional_quality_adversarial_eval_report.md",
  );
}

export function writeAdversarialReport(
  result: ReturnType<typeof runAdversarialEmotionalEval>,
  path = defaultAdversarialReportPath(),
): void {
  const lines = [
    "# Emotional Quality Adversarial Eval Report",
    "",
    `**Generated:** ${new Date().toISOString()}`,
    "",
    `**Status:** ${result.ok ? "PASS" : "FAIL"}`,
    "",
    "> Proxy eval only — not field proof. Metrics never log raw journal text.",
    "",
  ];
  if (result.failures.length) {
    lines.push("## Failures", "", ...result.failures.map((f) => `- ${f}`));
  }
  if (result.strictFails.length) {
    lines.push(
      "## Strict adversarial fails",
      "",
      ...result.strictFails.map((f) => `- ${f}`),
    );
  }
  try {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, lines.join("\n"));
  } catch {
    /* optional external report path */
  }
  const inRepo = resolve(process.cwd(), "docs/reports/emotional_quality_adversarial_eval_report.md");
  try {
    mkdirSync(dirname(inRepo), { recursive: true });
    writeFileSync(inRepo, lines.join("\n"));
  } catch {
    /* ignore */
  }
}
