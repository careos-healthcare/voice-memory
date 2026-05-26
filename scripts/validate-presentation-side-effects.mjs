#!/usr/bin/env node
/**
 * Fail when presentation build/pick/enrich paths call tracking or storage writes synchronously.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCANNED_FILES = [
  "lib/refinement/quiet-presentation.ts",
  "lib/refinement/revisit-experience.ts",
  "lib/refinement/callback-tuning.ts",
  "lib/revisit/resurfacing-confidence.ts",
  "lib/resurfacing/evidence-engine.ts",
  "lib/retention/day-two-return.ts",
];

const BUILD_FN_PATTERN =
  /export function (build[A-Za-z]+|pick[A-Za-z]+|enrich[A-Za-z]+)\s*\(/g;

const FORBIDDEN = [
  "observeCallbackShown",
  "trackLocalEvent",
  "recordLearningEvent",
  "commitDayTwoReturnOffer",
  "observeSessionFirst",
  "writeOnceFlag",
  "localStorage.setItem",
  "sessionStorage.setItem",
  "recordCallbackSurfaced",
  "observeMagicCallbackSurfaced",
  "rememberNoteContext",
  "markRevisitBoost",
  "recordEmotionalReopen",
  "resolveSilenceIntelligence",
];

function extractExportedFunctions(source) {
  const blocks = [];
  let match;
  BUILD_FN_PATTERN.lastIndex = 0;
  while ((match = BUILD_FN_PATTERN.exec(source)) !== null) {
    const name = match[1];
    const start = match.index;
    const braceStart = source.indexOf("{", match.index + match[0].length);
    if (braceStart === -1) continue;
    let depth = 0;
    let end = braceStart;
    for (let i = braceStart; i < source.length; i += 1) {
      const ch = source[i];
      if (ch === "{") depth += 1;
      else if (ch === "}") {
        depth -= 1;
        if (depth === 0) {
          end = i + 1;
          break;
        }
      }
    }
    blocks.push({ name, body: source.slice(braceStart, end) });
  }
  return blocks;
}

function assertRequiredFiles() {
  const required = [
    "lib/tracking/presentation-guard.ts",
    "lib/refinement/presentation-side-effects.ts",
    "lib/performance/resurfacing-cache.ts",
    "lib/entry/entry-route-guard.ts",
    "app/page.tsx",
    "app/entry/[id]/page.tsx",
  ];
  for (const rel of required) {
    if (!fs.existsSync(path.join(ROOT, rel))) {
      console.error(`Presentation side-effect validation failed — missing ${rel}`);
      process.exit(1);
    }
  }

  const page = fs.readFileSync(path.join(ROOT, "app/page.tsx"), "utf8");
  if (!page.includes("runPresentationBuild") || !page.includes("flushPresentationSideEffects")) {
    console.error(
      "Presentation side-effect validation failed — homepage must build under guard and flush after.",
    );
    process.exit(1);
  }

  const cache = fs.readFileSync(path.join(ROOT, "lib/performance/resurfacing-cache.ts"), "utf8");
  if (!cache.includes("runPresentationBuild") || !cache.includes("flushPresentationSideEffects")) {
    console.error(
      "Presentation side-effect validation failed — resurfacing cache must guard builds and flush.",
    );
    process.exit(1);
  }

  const entryPage = fs.readFileSync(path.join(ROOT, "app/entry/[id]/page.tsx"), "utf8");
  if (!entryPage.includes("shouldRunEntryPresentationBuilders")) {
    console.error(
      "Presentation side-effect validation failed — entry page must gate presentation builders.",
    );
    process.exit(1);
  }
  if (!entryPage.includes("runEntryPresentationSafe")) {
    console.error(
      "Presentation side-effect validation failed — entry page must use fail-closed presentation runtime.",
    );
    process.exit(1);
  }
}

assertRequiredFiles();

let failed = false;

for (const rel of SCANNED_FILES) {
  const filePath = path.join(ROOT, rel);
  if (!fs.existsSync(filePath)) {
    console.error(`Presentation side-effect validation failed — missing ${rel}`);
    process.exit(1);
  }
  const source = fs.readFileSync(filePath, "utf8");
  for (const { name, body } of extractExportedFunctions(source)) {
    for (const token of FORBIDDEN) {
      if (body.includes(token)) {
        console.error(
          `Presentation side-effect validation failed — ${rel} ${name}() must not call ${token}`,
        );
        failed = true;
      }
    }
  }
}

const provider = fs.readFileSync(
  path.join(ROOT, "components/homepage/HomepagePrimaryCtaProvider.tsx"),
  "utf8",
);
if (!provider.includes("registryRef") || !provider.includes("current === next")) {
  console.error(
    "Presentation side-effect validation failed — CTA provider must use ref registry and stable winner updates.",
  );
  failed = true;
}

if (failed) process.exit(1);

console.log("Presentation side-effect validation passed.");
