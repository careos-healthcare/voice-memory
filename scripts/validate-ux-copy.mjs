#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const PRIMARY_ROUTES = [
  "app/page.tsx",
  "app/journal/page.tsx",
  "app/memory/page.tsx",
  "app/pricing/page.tsx",
  "app/account/page.tsx",
  "app/export/page.tsx",
  "app/threads/page.tsx",
  "components/capture/RecordCaptureChrome.tsx",
  "components/continuity/FirstReturnMoment.tsx",
  "components/system/MemoryConfidence.tsx",
  "components/entry/EntryPrimaryCallback.tsx",
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
  { file: "components/pricing/PricingStaticShell.tsx", pattern: /Free/ },
  { file: "components/pricing/PricingStaticShell.tsx", pattern: /Pro/ },
  { file: "components/pricing/PricingStaticShell.tsx", pattern: /Checkout unavailable|Checkout available/ },
  { file: "components/system/MemoryConfidence.tsx", pattern: /Not me/ },
  { file: "components/system/MemoryConfidence.tsx", pattern: /That fits/ },
  { file: "components/system/MemoryConfidence.tsx", pattern: /Why this surfaced/ },
  { file: "components/capture/RecordCaptureChrome.tsx", pattern: /PrivacyNotice/ },
  { file: "components/entry/EntryPrimaryCallback.tsx", pattern: /MemoryConfidence/ },
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
