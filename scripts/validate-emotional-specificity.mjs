#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_DIRS = ["app", "components", "lib"];

const SKIP_PATH_PARTS = [
  `${path.sep}debug${path.sep}`,
  `${path.sep}api${path.sep}`,
  "packages/shared/lib/debug",
  "packages/shared/lib/marketing",
  "packages/shared/lib/archive/",
  "packages/shared/lib/sharing/",
  "packages/shared/lib/memory/memory-compounding.ts",
  "packages/shared/lib/validation",
  "packages/shared/lib/research",
  "packages/shared/lib/monetization",
  "packages/shared/lib/pilot",
  "packages/shared/lib/integrity",
  "packages/shared/lib/onboarding/onboarding-restraint.ts",
  "packages/shared/lib/memory-language.ts",
  "packages/shared/lib/resurfacing/emotional-specificity.ts",
  "packages/shared/lib/resurfacing/genericity-filter.ts",
  "packages/shared/lib/revisit/resurfacing-copy.ts",
  "scripts/",
  "apps/web/app/safety",
  "apps/web/app/privacy",
  "apps/web/app/terms",
  "apps/web/app/contact",
  "apps/web/app/launch",
  "apps/web/app/welcome",
  "apps/web/app/how-it-works",
];

const FORBIDDEN_RE = [
  { re: /\bpatterns may emerge\b/i, label: "patterns may emerge" },
  { re: /\b(?:healing|growth|inner)\s+journey\b/i, label: "vague journey" },
  { re: /\breflective mirror\b/i, label: "reflective mirror" },
  { re: /\bmemory intelligence\b/i, label: "memory intelligence" },
  { re: /\bdiscover patterns\b/i, label: "discover patterns" },
  { re: /\bemotional growth\b/i, label: "emotional growth" },
  { re: /\bself[- ]?growth\b/i, label: "self-growth" },
  { re: /\bunlock your insights\b/i, label: "unlock insights" },
];

const STRING_LIT_RE =
  /(`(?:\\.|[^`\\])*`|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')/g;

function shouldSkip(filePath) {
  const rel = path.relative(ROOT, filePath);
  return SKIP_PATH_PARTS.some((part) => rel.includes(part.replace(/\//g, path.sep)));
}

function scanFile(filePath, violations) {
  const content = fs.readFileSync(filePath, "utf8");
  const rel = path.relative(ROOT, filePath);
  let match;
  while ((match = STRING_LIT_RE.exec(content)) !== null) {
    const literal = match[1];
    const unquoted = literal.slice(1, -1);
    if (unquoted.length < 12) continue;
    for (const { re, label } of FORBIDDEN_RE) {
      if (re.test(unquoted)) {
        violations.push({ file: rel, label, sample: unquoted.slice(0, 80) });
        break;
      }
    }
  }
}

function walk(dir, violations) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, violations);
      continue;
    }
    if (!/\.(tsx?|jsx?|mjs)$/.test(entry.name)) continue;
    if (shouldSkip(full)) continue;
    scanFile(full, violations);
  }
}

const violations = [];
for (const dir of SCAN_DIRS) {
  const full = path.join(ROOT, dir);
  if (fs.existsSync(full)) walk(full, violations);
}

if (violations.length > 0) {
  console.error("validate-emotional-specificity: failed\n");
  for (const row of violations.slice(0, 30)) {
    console.error(`  ${row.file}: ${row.label}`);
    console.error(`    ${row.sample}`);
  }
  if (violations.length > 30) {
    console.error(`  …and ${violations.length - 30} more`);
  }
  process.exit(1);
}

console.log("validate-emotional-specificity: ok");
