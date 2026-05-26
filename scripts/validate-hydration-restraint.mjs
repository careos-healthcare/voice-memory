#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_FILES = [
  "components/ActivationOnboarding.tsx",
  "components/OnboardingBanner.tsx",
  "components/PersonalisationProgressNote.tsx",
  "components/onboarding/CalmComprehensionPrompt.tsx",
  "components/onboarding/OnboardingNavigationTracker.tsx",
  "components/social-proof/OnboardingCompletionProof.tsx",
  "components/social-proof/OnboardingTrustLine.tsx",
];

const BROWSER_READ_RE =
  /typeof\s+window|localStorage|sessionStorage|navigator\.|Date\.now\s*\(|Math\.random\s*\(/;

const USE_STATE_LAZY_RE = /useState\s*\(\s*\(\)\s*=>/;

function stripUseEffectCalls(source) {
  let result = "";
  let i = 0;
  while (i < source.length) {
    const idx = source.indexOf("useEffect", i);
    if (idx === -1) {
      result += source.slice(i);
      break;
    }
    result += source.slice(i, idx);
    i = idx + "useEffect".length;
    if (source[i] !== "(") {
      result += "useEffect";
      continue;
    }
    let depth = 0;
    let started = false;
    while (i < source.length) {
      const ch = source[i];
      if (ch === "(") {
        depth += 1;
        started = true;
      } else if (ch === ")") {
        depth -= 1;
        if (started && depth === 0) {
          i += 1;
          break;
        }
      }
      i += 1;
    }
  }
  return result;
}

function collectLazyUseStateBlocks(source) {
  const blocks = [];
  const re = /useState\s*\(\s*\(\)\s*=>/g;
  let match;
  while ((match = re.exec(source)) !== null) {
    let depth = 0;
    let j = match.index + match[0].length;
    let started = false;
    while (j < source.length) {
      const ch = source[j];
      if (ch === "(") {
        depth += 1;
        started = true;
      } else if (ch === ")") {
        if (!started) break;
        depth -= 1;
        if (depth === 0) {
          blocks.push(source.slice(match.index, j + 1));
          break;
        }
      }
      j += 1;
    }
  }
  return blocks;
}

const violations = [];

for (const rel of SCAN_FILES) {
  const abs = path.join(ROOT, rel);
  if (!fs.existsSync(abs)) {
    violations.push(`${rel}: missing file`);
    continue;
  }
  const content = fs.readFileSync(abs, "utf8");

  for (const block of collectLazyUseStateBlocks(content)) {
    if (BROWSER_READ_RE.test(block)) {
      violations.push(`${rel}: browser-only read in useState initializer`);
    }
  }

  const renderBody = stripUseEffectCalls(content);
  if (BROWSER_READ_RE.test(renderBody)) {
    violations.push(`${rel}: browser-only read outside useEffect`);
  }
}

if (violations.length > 0) {
  console.error("Hydration restraint validation failed:\n");
  for (const v of violations) console.error(`  ${v}`);
  process.exit(1);
}

console.log(`Hydration restraint validation passed (${SCAN_FILES.length} files scanned).`);
