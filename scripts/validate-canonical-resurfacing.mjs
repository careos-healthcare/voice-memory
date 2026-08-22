#!/usr/bin/env node
import fs from "node:fs";

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
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { runCanonicalResurfacingPipeline } from "../packages/shared/lib/resurfacing/canonical-resurfacing-pipeline.ts";
import { containsOverconfidentResurfacingCopy } from "../packages/shared/lib/resurfacing/resurfacing-ambiguity.ts";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const USER_FACING_LOGIC = [
  "apps/web/components/entry/EntryPrimaryCallback.tsx",
  "packages/shared/lib/continuity/first-return-moment.ts",
  "packages/shared/lib/refinement/callback-tuning.ts",
  "packages/shared/lib/resurfacing/evidence-engine.ts",
];

const USER_FACING_UI = ["apps/web/components/continuity/FirstReturnMoment.tsx"];

const FORBIDDEN_IMPORTS = [
  "resurfacing-evidence-gate",
  "applyEvidenceGateFor",
  "applyResurfacingEvidenceGate",
  "buildResurfacingEvidence",
];

for (const rel of USER_FACING_LOGIC) {
  const text = fs.readFileSync(path.join(ROOT, rel), "utf8");
  for (const token of FORBIDDEN_IMPORTS) {
    if (text.includes(token)) {
      failures.push(`${rel} must use canonical-resurfacing-pipeline, found ${token}`);
    }
  }
  if (!text.includes("canonical-resurfacing-pipeline")) {
    failures.push(`${rel} must import canonical-resurfacing-pipeline`);
  }
}

for (const rel of USER_FACING_UI) {
  const text = fs.readFileSync(path.join(ROOT, rel), "utf8");
  for (const token of FORBIDDEN_IMPORTS) {
    if (text.includes(token)) {
      failures.push(`${rel} must not bypass canonical pipeline, found ${token}`);
    }
  }
  if (!text.includes("pickFirstReturnMoment")) {
    failures.push(`${rel} must use pickFirstReturnMoment (canonical-backed)`);
  }
}

const entry = fs.readFileSync(path.join(ROOT, "apps/web/components/entry/EntryPrimaryCallback.tsx"), "utf8");
if (!entry.includes("runCanonicalPipelineForMemoryNote")) {
  failures.push("EntryPrimaryCallback must use runCanonicalPipelineForMemoryNote");
}

const noEvidence = runCanonicalResurfacingPipeline({
  quote: "stressed",
  appearances: 1,
});
if (noEvidence.show) {
  failures.push("no evidence must not show");
}

const ambiguous = runCanonicalResurfacingPipeline({
  quote: '"yeah right everything is totally fine lol"',
  appearances: 3,
  gapDays: 2,
});
if (ambiguous.show && containsOverconfidentResurfacingCopy(ambiguous.callbackText)) {
  failures.push("ambiguous sarcasm must not show overconfident copy");
}

const strong = runCanonicalResurfacingPipeline({
  quote: '"I keep putting off calling the dentist — same excuse again"',
  appearances: 4,
  gapDays: 5,
  threadType: "repeated_phrase",
});
if (!strong.show) {
  failures.push("strong evidence callback should show");
}
if (
  strong.show &&
  !strong.whySurfacedLines[0]?.toLowerCase().includes("might") &&
  strong.safeDisplayMode === "cautious"
) {
  /* cautious ok */
}

if (!fs.existsSync(path.join(ROOT, "packages/shared/lib/resurfacing/canonical-resurfacing-pipeline.ts"))) {
  failures.push("missing canonical-resurfacing-pipeline.ts");
}

if (failures.length) {
  console.error("validate-canonical-resurfacing failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-canonical-resurfacing ok");
