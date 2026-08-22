#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "packages/shared/lib/performance/debug-isolation.ts",
  "packages/shared/lib/performance/lightweight-mode.ts",
  "packages/shared/lib/performance/perf-instrumentation.ts",
  "packages/shared/lib/performance/phrase-scan-cache.ts",
  "packages/shared/lib/performance/resurfacing-cache.ts",
  "packages/shared/lib/debug/performance-health.ts",
  "apps/web/components/internal/PerformanceHealthPanel.tsx",
  "apps/web/app/internal/performance-health/page.tsx",
  "packages/shared/lib/local-analytics.ts",
  "packages/shared/lib/storage.ts",
];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Performance validation failed — missing ${rel}`);
    process.exit(1);
  }
}

const analytics = fs.readFileSync(path.join(ROOT, "packages/shared/lib/local-analytics.ts"), "utf8");
const storage = fs.readFileSync(path.join(ROOT, "packages/shared/lib/storage.ts"), "utf8");
const entryPage = fs.readFileSync(path.join(ROOT, "apps/web/app/entry/[id]/page.tsx"), "utf8");
const recorder = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
const phraseMemory = fs.readFileSync(path.join(ROOT, "packages/shared/lib/patterns/phrase-memory.ts"), "utf8");
const transcript = fs.readFileSync(path.join(ROOT, "packages/shared/lib/transcript/transcript-cleanup.ts"), "utf8");
const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");

const analyticsChecks = [
  "scheduleFlush",
  "FLUSH_DEBOUNCE_MS",
  "getLightweightLimits",
  "knownNames",
  "flushing",
];

for (const token of analyticsChecks) {
  if (!analytics.includes(token)) {
    console.error(`Performance validation failed — analytics missing ${token}`);
    process.exit(1);
  }
}

if (!storage.includes("memoryEligibleCache") || !storage.includes("bumpMemoryEligibleCache")) {
  console.error("Performance validation failed — entries cache not wired in storage.");
  process.exit(1);
}

if (!phraseMemory.includes("getCachedPhraseMemory")) {
  console.error("Performance validation failed — phrase scan cache not wired.");
  process.exit(1);
}

const usesPresentationCache =
  entryPage.includes("readCachedQuietEntryPresentation") ||
  entryPage.includes("getCachedQuietEntryPresentation");
if (!usesPresentationCache || !entryPage.includes("needsHeavyMemoryBlocks")) {
  console.error("Performance validation failed — entry page missing resurfacing cache / heavy block gating.");
  process.exit(1);
}

if (!recorder.includes("prepareTranscriptForSaveOnce") || !recorder.includes("processingRef")) {
  console.error("Performance validation failed — recorder stabilization missing.");
  process.exit(1);
}

if (!transcript.includes("prepareTranscriptForSaveOnce")) {
  console.error("Performance validation failed — transcript cleanup dedupe missing.");
  process.exit(1);
}

const prodCritical = [entryPage, recorder];
for (const source of prodCritical) {
  if (source.includes("@/lib/debug/")) {
    console.error("Performance validation failed — debug module imported in production-critical path.");
    process.exit(1);
  }
}

if (!packageJson.includes("validate:performance")) {
  console.error("Performance validation failed — npm script not wired.");
  process.exit(1);
}

console.log("Performance restraint validation passed.");
