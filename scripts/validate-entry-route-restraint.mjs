#!/usr/bin/env node
/**
 * Entry route must fail closed: invalid ids skip builders; heavy work deferred after mount.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const ENTRY_PAGE = path.join(ROOT, "app/entry/[id]/page.tsx");

const REQUIRED = [
  "lib/entry/entry-route-guard.ts",
  "lib/entry/entry-presentation-runtime.ts",
  "lib/entry/defer-after-mount.ts",
  "app/entry/[id]/page.tsx",
];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Entry route validation failed — missing ${rel}`);
    process.exit(1);
  }
}

const page = fs.readFileSync(ENTRY_PAGE, "utf8");

const requiredTokens = [
  "normalizeEntryRouteId",
  "isInvalidEntryRouteId",
  "shouldRunEntryPresentationBuilders",
  "scheduleAfterMount",
  "runEntryPresentationSafe",
  "heavyReady",
  "Moment not found",
];

for (const token of requiredTokens) {
  if (!page.includes(token)) {
    console.error(`Entry route validation failed — app/entry/[id]/page.tsx missing ${token}`);
    process.exit(1);
  }
}

const jsxReturn = page.slice(page.lastIndexOf("return ("));
const forbiddenInJsx = [
  "getCachedQuietEntryPresentation(",
  "getCachedRevisitExperience(",
  "buildQuietEntryPresentation(",
  "buildRevisitExperience(",
  "getMemoryEligibleEntries()",
  "trackLocalEvent(",
  "localStorage.setItem",
  "sessionStorage.setItem",
  "entryMemoryNotes(",
  "buildFollowupPrompt(",
];

for (const token of forbiddenInJsx) {
  if (jsxReturn.includes(token)) {
    console.error(
      `Entry route validation failed — entry JSX must not call ${token}`,
    );
    process.exit(1);
  }
}

if (
  page.includes("getCachedQuietEntryPresentation(") &&
  !page.includes("scheduleAfterMount")
) {
  console.error(
    "Entry route validation failed — cached presentation must be scheduled after mount.",
  );
  process.exit(1);
}

if (!page.includes("queueMicrotask") || !page.includes("trackRevisitOpened")) {
  console.error(
    "Entry route validation failed — revisit analytics must be deferred (queueMicrotask).",
  );
  process.exit(1);
}

console.log("Entry route restraint validation passed.");
