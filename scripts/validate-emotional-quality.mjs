#!/usr/bin/env node
import { runAplusEmotionalEval, writeAplusEmotionalReport } from "../lib/emotional-quality/run-aplus-eval.ts";
import {
  runAdversarialEmotionalEval,
  writeAdversarialReport,
} from "../lib/emotional-quality/run-adversarial-eval.ts";

import { clearResurfacingFeedbackForEval } from "../lib/resurfacing/resurfacing-feedback.ts";

const storage = new Map();

globalThis.localStorage = {
  getItem: (k) => storage.get(String(k)) ?? null,
  setItem: (k, v) => storage.set(String(k), String(v)),
  removeItem: (k) => storage.delete(String(k)),
  clear: () => storage.clear(),
  get length() {
    return storage.size;
  },
  key: (i) => [...storage.keys()][i] ?? null,
};

clearResurfacingFeedbackForEval();

const { ok, failures, metrics } = runAplusEmotionalEval();
writeAplusEmotionalReport({ ok, failures, metrics });

const adversarial = runAdversarialEmotionalEval();
writeAdversarialReport(adversarial);

console.log(
  JSON.stringify(
    {
      precisionProxy: metrics.precisionProxy,
      quoteBackedRate: metrics.quoteBackedRate,
      genericFalsePositiveRate: metrics.genericFalsePositiveRate,
      notMePenaltyEffective: metrics.notMePenaltyEffective,
    },
    null,
    2,
  ),
);

if (!ok || !adversarial.ok) {
  const all = [...failures, ...adversarial.failures, ...adversarial.strictFails];
  console.error("validate-emotional-quality failed:\n", all.join("\n"));
  process.exit(1);
}
clearResurfacingFeedbackForEval();
console.log("validate-emotional-quality ok");
