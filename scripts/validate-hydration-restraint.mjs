#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const SCAN_FILES = [
  "apps/web/components/ActivationOnboarding.tsx",
  "apps/web/components/OnboardingBanner.tsx",
  "apps/web/components/PersonalisationProgressNote.tsx",
  "apps/web/components/onboarding/CalmComprehensionPrompt.tsx",
  "apps/web/components/onboarding/OnboardingNavigationTracker.tsx",
  "apps/web/components/social-proof/OnboardingCompletionProof.tsx",
  "apps/web/components/social-proof/OnboardingTrustLine.tsx",
  "apps/web/components/homepage/HomepagePrimaryCtaProvider.tsx",
  "apps/web/components/retention/DayTwoReturnPrompt.tsx",
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

  if (/\[ctx\b/.test(content) || /useEffect\([^)]*\[[^\]]*\bctx\b/.test(content)) {
    violations.push(`${rel}: useEffect depends on unstable context object`);
  }
  if (/useEffect\(\s*[\s\S]*?\[\s*limits\s*,/m.test(content)) {
    violations.push(`${rel}: useEffect depends on whole limits object`);
  }
}

if (violations.length > 0) {
  console.error("Hydration restraint validation failed:\n");
  for (const v of violations) console.error(`  ${v}`);
  process.exit(1);
}

console.log(`Hydration restraint validation passed (${SCAN_FILES.length} files scanned).`);
