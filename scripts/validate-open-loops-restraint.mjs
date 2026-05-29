#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "types/open-loop.ts",
  "lib/open-loops/open-loop-storage.ts",
  "lib/open-loops/unresolved-signals.ts",
  "lib/open-loops/open-loop-copy.ts",
  "lib/open-loops/open-loop-continuity.ts",
  "lib/open-loops/open-loop-resurfacing-lines.ts",
  "lib/open-loops/open-loop-activation.ts",
  "lib/open-loops/open-loop-activation-audit.ts",
  "lib/open-loops/open-loop-activation-debug.ts",
  "lib/open-loops/unresolved-cache.ts",
  "lib/open-loops/unresolved-detect-core.ts",
  "lib/open-loops/open-loop-performance.ts",
  "lib/open-loops/open-loop-defer.ts",
  "lib/runtime/render-safe.ts",
  "lib/runtime/read-model.ts",
  "lib/runtime/write-actions.ts",
  "lib/runtime/deferred-jobs.ts",
  "app/internal/open-loop-performance/page.tsx",
  "lib/open-loops/open-loop-return-prompt.ts",
  "app/internal/open-loop-activation/page.tsx",
  "lib/open-loops/open-loop-silence.ts",
  "lib/open-loops/emotional-shift.ts",
  "lib/open-loops/open-loop-readout.ts",
  "lib/open-loops/open-loop-observation.ts",
  "app/internal/open-loops-readout/page.tsx",
  "components/entry/OpenLoopNextStepPrompt.tsx",
  "components/open-loops/OpenLoopCard.tsx",
  "components/open-loops/OpenLoopsList.tsx",
  "app/open-loops/page.tsx",
];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  "app/internal/open-loops-readout/",
  "lib/open-loops/",
  "components/entry/OpenLoopNextStepPrompt.tsx",
  "components/open-loops/",
  "app/open-loops/",
  "scripts/",
];

const USER_FACING_BANNED = [
  { re: /\baction plan\b/i, label: "action plan" },
  { re: /\bcoaching plan\b/i, label: "coaching plan" },
  { re: /\b(?:we|you) should\b/i, label: "prescriptive should" },
  { re: /\btry this\b/i, label: "try this" },
  { re: /\bwellness\b/i, label: "wellness" },
  { re: /\btherapy\b/i, label: "therapy" },
  { re: /\bself-care\b/i, label: "self-care" },
  { re: /\bai[- ]generated\b/i, label: "AI-generated" },
  { re: /\brecommend(?:ation)?s?\b/i, label: "recommended" },
  { re: /\bcoping\b/i, label: "coping" },
  { re: /\bhealing journey\b/i, label: "healing journey" },
  { re: /\btask\b/i, label: "task" },
  { re: /\bproductivity\b/i, label: "productivity" },
  { re: /\bgoal tracking\b/i, label: "goal tracking" },
  { re: /\bhabit\b/i, label: "habit" },
  { re: /\bcomplete your plan\b/i, label: "complete your plan" },
  { re: /\bdue date\b/i, label: "due date" },
  { re: /\bnotification\b/i, label: "notification" },
  { re: /\bstreak\b/i, label: "streak" },
  { re: /\bkanban\b/i, label: "kanban" },
  { re: /\bdashboard\b/i, label: "dashboard" },
];

const EXT = new Set([".tsx", ".ts"]);
const SCAN_DIRS = ["app", "components"];

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Open loops restraint validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const typesFile = fs.readFileSync(path.join(ROOT, "types/open-loop.ts"), "utf8");
for (const token of [
  "openLoopId",
  "sourceEntryId",
  "lastMentionedAt",
  "recurrenceCount",
  "firstSeenAt",
  "strongestAnchorPhrase",
  "emotionalShiftSummary",
  "connectedMoments",
  "closureNote",
  "softened",
]) {
  if (!typesFile.includes(token)) {
    console.error(`Open loops validation failed — types/open-loop.ts missing ${token}.`);
    process.exit(1);
  }
}

const linesFile = fs.readFileSync(
  path.join(ROOT, "lib/open-loops/open-loop-resurfacing-lines.ts"),
  "utf8",
);
if (!linesFile.includes("passesResurfacingGenericityGate")) {
  console.error("Open loops validation failed — resurfacing must use genericity gate.");
  process.exit(1);
}

const copyFile = fs.readFileSync(path.join(ROOT, "lib/open-loops/open-loop-copy.ts"), "utf8");
for (const token of [
  "Earlier moments connected to this",
  "What changed?",
  "Threads still open",
]) {
  if (!copyFile.includes(token)) {
    console.error(`Open loops validation failed — open-loop-copy missing "${token}".`);
    process.exit(1);
  }
}

const storage = fs.readFileSync(path.join(ROOT, "lib/open-loops/open-loop-storage.ts"), "utf8");
for (const token of ["closeOpenLoop", "pickOpenLoopResurfacingLine", "recurrenceCount"]) {
  if (!storage.includes(token)) {
    console.error(`Open loops validation failed — storage must include ${token}.`);
    process.exit(1);
  }
}

function shouldSkip(filePath) {
  const rel = path.relative(ROOT, filePath);
  return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
}

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    if (shouldSkip(full)) continue;
    const stat = fs.statSync(full);
    if (stat.isDirectory()) walk(full, out);
    else if (EXT.has(path.extname(name))) out.push(full);
  }
  return out;
}

const violations = [];
for (const file of SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)))) {
  const rel = path.relative(ROOT, file);
  if (!rel.includes("open-loops") && !rel.includes("OpenLoop")) continue;

  const content = fs.readFileSync(file, "utf8");
  content.split("\n").forEach((line, index) => {
    const trimmed = line.trim();
    if (trimmed.startsWith("//") || trimmed.startsWith("*")) return;
    for (const { re, label } of USER_FACING_BANNED) {
      if (re.test(line)) {
        violations.push({ file, line: index + 1, label, text: trimmed.slice(0, 120) });
      }
    }
  });
}

if (violations.length > 0) {
  console.error("Open loops restraint validation failed:\n");
  for (const row of violations) {
    console.error(`  ${path.relative(ROOT, row.file)}:${row.line} — banned "${row.label}"`);
    console.error(`    ${row.text}\n`);
  }
  process.exit(1);
}

console.log("Open loops restraint validation passed.");
