#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const PRIMARY_ROUTES = [
  "apps/web/app/page.tsx",
  "apps/web/app/journal/page.tsx",
  "apps/web/app/memory/page.tsx",
  "apps/web/app/pricing/page.tsx",
  "apps/web/app/account/page.tsx",
  "apps/web/app/export/page.tsx",
  "apps/web/app/threads/page.tsx",
  "apps/web/components/capture/RecordCaptureChrome.tsx",
  "apps/web/components/continuity/FirstReturnMoment.tsx",
  "apps/web/components/system/MemoryConfidence.tsx",
  "apps/web/components/entry/EntryPrimaryCallback.tsx",
];

const BANNED = [
  /\bai journal\b/i,
  /\binsight engine\b/i,
  /\bemotional intelligence engine\b/i,
  /\bunlock your potential\b/i,
  /\bhealing journey\b/i,
  /\bwe detected that you\b/i,
  /\byour emotional score\b/i,
  /\bactive Pro\b/i,
  /\bpayment complete\b/i,
  /\bplaceholder pricing\b/i,
  /\bno Stripe yet\b/i,
  /\byour ai coach\b/i,
  /\bpersonalized insights just for you\b/i,
];

const REQUIRED_TRUST = [
  { file: "apps/web/components/pricing/PricingStaticShell.tsx", pattern: /Free/ },
  { file: "apps/web/components/pricing/PricingStaticShell.tsx", pattern: /Pro/ },
  { file: "apps/web/components/pricing/PricingStaticShell.tsx", pattern: /Checkout unavailable|Checkout available/ },
  { file: "apps/web/components/system/MemoryConfidence.tsx", pattern: /Not me/ },
  { file: "apps/web/components/system/MemoryConfidence.tsx", pattern: /That fits/ },
  { file: "apps/web/components/system/MemoryConfidence.tsx", pattern: /Why this surfaced/ },
  { file: "apps/web/components/capture/RecordCaptureChrome.tsx", pattern: /PrivacyNotice/ },
  { file: "apps/web/components/entry/EntryPrimaryCallback.tsx", pattern: /MemoryConfidence/ },
];

for (const rel of PRIMARY_ROUTES) {
  const file = path.join(ROOT, rel);
  if (!fs.existsSync(file)) {
    failures.push(`missing route file ${rel}`);
    continue;
  }
  const text = fs.readFileSync(file, "utf8");
  for (const re of BANNED) {
    if (re.test(text)) failures.push(`${rel}: banned UX phrase ${re}`);
  }
}

for (const { file, pattern } of REQUIRED_TRUST) {
  const text = fs.readFileSync(path.join(ROOT, file), "utf8");
  if (!pattern.test(text)) failures.push(`${file}: missing required trust/copy pattern`);
}

if (failures.length) {
  console.error("validate-ux-copy failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-ux-copy ok");
