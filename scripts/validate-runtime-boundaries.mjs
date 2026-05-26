#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/runtime/render-safe.ts",
  "lib/runtime/read-model.ts",
  "lib/runtime/write-actions.ts",
  "lib/runtime/deferred-jobs.ts",
];

const READ_MODEL_FORBIDDEN = [
  "localStorage.setItem",
  "sessionStorage.setItem",
  "refreshOpenLoopContinuity(",
  "refreshAllOpenLoopContinuity(",
  "writeLoops(",
  "trackLocalEvent",
  "trackOpenLoop",
  "createOpenLoopInStore",
  "maybeLinkReflectionAfterOpenLoopResurface",
];

const UI_COMPONENTS = [
  "components/entry/OpenLoopNextStepPrompt.tsx",
  "components/open-loops/OpenLoopEntryContinuity.tsx",
  "components/open-loops/OpenLoopCard.tsx",
  "components/open-loops/OpenLoopReturnPrompt.tsx",
  "components/clarity/SortThisOutAloudPrompt.tsx",
  "components/clarity/CirclingThoughtsSection.tsx",
];

const UI_FORBIDDEN_IMPORTS = [
  { from: "@/lib/open-loops/open-loop-storage", names: ["createOpenLoop", "dismissOpenLoopPrompt", "closeOpenLoop", "updateOpenLoopStatus", "touchRelatedEntry"] },
  { from: "@/lib/open-loops/open-loop-observation", names: ["trackOpenLoop"] },
];

const failures = [];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const readModel = fs.readFileSync(path.join(ROOT, "lib/runtime/read-model.ts"), "utf8");
for (const token of READ_MODEL_FORBIDDEN) {
  if (readModel.includes(token)) {
    failures.push(`read-model.ts must not contain ${token}`);
  }
}
if (!readModel.includes("runReadOnly")) {
  failures.push("read-model.ts must wrap selectors with runReadOnly");
}

const writeActions = fs.readFileSync(path.join(ROOT, "lib/runtime/write-actions.ts"), "utf8");
if (!writeActions.includes("runWriteAction")) {
  failures.push("write-actions.ts must use runWriteAction");
}

const deferred = fs.readFileSync(path.join(ROOT, "lib/runtime/deferred-jobs.ts"), "utf8");
for (const job of [
  "refresh-open-loop-continuity",
  "link-reflection-after-resurface",
  "extract-thought-patterns",
]) {
  if (!deferred.includes(job)) failures.push(`deferred-jobs.ts missing ${job}`);
}

const storage = fs.readFileSync(path.join(ROOT, "lib/open-loops/open-loop-storage.ts"), "utf8");
if (storage.includes("getAllOpenLoops(): OpenLoop[] {\n  return sortLoops(withFreshContinuity")) {
  failures.push("getAllOpenLoops must not refresh continuity on read");
}

for (const rel of UI_COMPONENTS) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  for (const rule of UI_FORBIDDEN_IMPORTS) {
    if (src.includes(rule.from)) {
      for (const name of rule.names) {
        if (src.includes(name)) {
          failures.push(`${rel}: UI must not import ${name} from storage/observation — use runtime write-actions`);
        }
      }
    }
  }
  if (!src.includes("read-model") && !src.includes("write-actions") && rel.includes("OpenLoopNextStep")) {
    failures.push(`${rel}: must use runtime read-model / write-actions`);
  }
}

const entryPage = fs.readFileSync(path.join(ROOT, "app/entry/[id]/page.tsx"), "utf8");
if (entryPage.includes("readCachedQuietEntryPresentation") && entryPage.includes("getCachedQuietEntryPresentation")) {
  failures.push("entry page: use readCached* not getCached* for presentation");
}
if (!entryPage.includes("enqueueRefreshOpenLoopContinuity")) {
  failures.push("entry page must enqueue deferred open-loop continuity refresh");
}

if (failures.length > 0) {
  console.error("Runtime boundary validation failed:\n");
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}

console.log("Runtime boundary validation passed.");
