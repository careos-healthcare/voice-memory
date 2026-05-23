#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "components", "lib"];
const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "app/safety",
  "app/privacy",
  "app/terms",
  "app/contact",
  "lib/trust-copy.ts",
  "lib/patterns/usefulness-filter.ts",
  "lib/patterns/note-limits.ts",
  "lib/patterns/changes.ts",
  "lib/patterns/calmness.ts",
  "lib/patterns/continuity-engine.ts",
  "lib/patterns/pattern-engine.ts",
  "lib/observation-language.ts",
  "lib/weekly-intelligence.ts",
  "lib/memory/resurfacing.ts",
  "lib/memory/time-memory.ts",
  "lib/memory/revisitation.ts",
  "lib/memory/change-moments.ts",
  "lib/memory/recovery-memory.ts",
  "lib/memory/familiarity.ts",
  "lib/memory/rhythm-memory.ts",
  "lib/memory/familiarity-resurfacing.ts",
  "lib/memory/resurfacing-priority.ts",
  "lib/memory/emotional-weight.ts",
  "lib/memory/archive-growth.ts",
  "lib/conversation/conversation-continuity.ts",
  "lib/conversation/followup-prompts.ts",
  "components/InsightCard.tsx",
  "components/patterns/AvoidanceCard.tsx",
  "components/patterns/CalmUnderstandingCard.tsx",
  "components/patterns/ContradictionContinuityCard.tsx",
  "components/patterns/LongitudinalContinuityCard.tsx",
  "components/patterns/PatternInsightCard.tsx",
  "components/patterns/ThenVsNowCard.tsx",
  "components/patterns/WhatChangedCard.tsx",
];

const BANNED = [
  { re: /\bpattern engine\b/i, label: "pattern engine" },
  { re: /\bemotional intelligence\b/i, label: "emotional intelligence" },
  { re: /\bpsychological\b/i, label: "psychological" },
  { re: /\btherapy-style\b/i, label: "therapy-style" },
  { re: /\bdiagnostic\b/i, label: "diagnostic" },
  { re: /\bconfidence score\b/i, label: "confidence score" },
  { re: /\binsight generated\b/i, label: "insight generated" },
  { re: /\bsignal detected\b/i, label: "signal detected" },
  { re: /\banalysis dashboard\b/i, label: "analysis dashboard" },
];

const CONTEXT_BANNED = [
  { re: /\banalysis\b/i, label: "analysis" },
  { re: /\bdetected\b/i, label: "detected" },
  { re: /\bconfidence\b/i, label: "confidence" },
  { re: /\binsight\b/i, label: "insight" },
];

const EXT = new Set([".tsx", ".ts", ".jsx", ".js"]);

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

function checkLine(line, filePath, lineNo, violations) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith("//") || trimmed.startsWith("*")) return;
  if (trimmed.includes("validate:quiet-copy")) return;

  for (const { re, label } of BANNED) {
    if (re.test(line)) {
      violations.push({ filePath, lineNo, word: label, line: trimmed.slice(0, 120) });
    }
  }

  const isUserFacing =
    filePath.includes(`${path.sep}app${path.sep}`) ||
    filePath.includes(`${path.sep}components${path.sep}`);
  if (isUserFacing) {
    for (const { re, label } of CONTEXT_BANNED) {
      if (re.test(line)) {
        violations.push({ filePath, lineNo, word: label, line: trimmed.slice(0, 120) });
      }
    }
  }
}

const files = SCAN_DIRS.flatMap((d) => walk(path.join(ROOT, d)));
const violations = [];

for (const file of files) {
  const content = fs.readFileSync(file, "utf8");
  content.split("\n").forEach((line, i) => checkLine(line, file, i + 1, violations));
}

if (violations.length > 0) {
  console.error(`validate:quiet-copy failed — ${violations.length} issue(s):\n`);
  for (const v of violations.slice(0, 40)) {
    const rel = path.relative(ROOT, v.filePath);
    console.error(`  ${rel}:${v.lineNo}  [${v.word}]  ${v.line}`);
  }
  if (violations.length > 40) {
    console.error(`  … and ${violations.length - 40} more`);
  }
  process.exit(1);
}

console.log(`validate:quiet-copy passed (${files.length} files scanned)`);
