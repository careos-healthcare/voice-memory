#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "packages/shared/lib/retention/first-week.ts",
  "packages/shared/lib/retention/gentle-return-prompts.ts",
  "packages/shared/lib/retention/archive-attachment-signals.ts",
  "packages/shared/lib/retention/archive-value-moments.ts",
  "packages/shared/lib/retention/first-week-observation.ts",
  "packages/shared/lib/retention/first-magic-moment.ts",
  "packages/shared/lib/retention/recurrence-density.ts",
  "packages/shared/lib/revisit/first-meaningful-revisit.ts",
  "apps/web/components/retention/GentleReturnPrompt.tsx",
  "apps/web/components/retention/ArchiveValueMoments.tsx",
  "packages/shared/lib/debug/first-week-retention.ts",
  "packages/shared/lib/debug/first-magic-moment-review.ts",
  "packages/shared/lib/debug/recurrence-density-review.ts",
  "apps/web/app/internal/first-week-retention/page.tsx",
  "apps/web/app/internal/first-magic-moment/page.tsx",
  "apps/web/app/internal/recurrence-density/page.tsx",
  "apps/web/components/internal/RecurrenceDensityDebugPanel.tsx",
  "packages/shared/types/first-week-retention.ts",
  "packages/shared/types/first-magic-moment.ts",
  "packages/shared/types/recurrence-density.ts",
];

const REQUIRED_EVENTS = [
  "first_revisit_completed",
  "first_callback_landed",
  "early_archive_attachment",
  "return_prompt_opened",
  "reflection_after_prompt",
  "silence_helped_return",
  "revisit_emotional_payoff",
];

const MAGIC_EVENTS = [
  "magic_candidate_created",
  "magic_candidate_shown",
  "magic_candidate_opened",
  "magic_candidate_saved",
  "magic_candidate_shared",
  "magic_followup_recorded",
  "magic_return_after_callback",
];

const RECURRENCE_DENSITY_EVENTS = [
  "recurrence_density_signal_detected",
  "recurrence_density_prompt_shown",
  "recurrence_density_prompt_dismissed",
  "recurrence_density_prompt_engaged",
  "recurrence_density_onboarding_complete",
];

const REQUIRED_COPY = [
  "You may want to leave another note before this week disappears.",
  "Something from earlier this week may feel different now.",
  "You used similar words before.",
  "This is starting to become a record of a real period.",
  "Record again about this when it shows up.",
  "If this comes back, say it in your own words.",
  "This may be worth recording again later.",
  "Use the same words if they still fit.",
  "The pattern gets clearer when your own words repeat.",
];

const FORBIDDEN_RE = [
  { re: /\bstreak\b/i, label: "streak" },
  { re: /\bdaily habit\b/i, label: "daily habit" },
  { re: /\bdon't miss\b/i, label: "don't miss" },
  { re: /\bproductivity\b/i, label: "productivity" },
  { re: /\bhabit goal\b/i, label: "habit goal" },
  { re: /\bdopamine\b/i, label: "dopamine" },
  { re: /\bengagement bait\b/i, label: "engagement bait" },
  { re: /\bkeep your streak\b/i, label: "keep your streak" },
  { re: /\bFOMO\b/i, label: "FOMO" },
];

const USER_SCAN_DIRS = ["apps/web/components/retention", "packages/shared/lib/retention/archive-value-moments.ts"];

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Retention restraint validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const observation = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/retention/first-week-observation.ts"),
  "utf8",
);
for (const event of REQUIRED_EVENTS) {
  if (!observation.includes(event)) {
    console.error(`Retention restraint validation failed — missing event: ${event}`);
    process.exit(1);
  }
}

const magicMoment = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/retention/first-magic-moment.ts"),
  "utf8",
);
for (const event of MAGIC_EVENTS) {
  if (!magicMoment.includes(event)) {
    console.error(`Retention restraint validation failed — missing magic event: ${event}`);
    process.exit(1);
  }
}
if (!magicMoment.includes("timeUntilFirstMeaningfulCallbackMs") || !magicMoment.includes("callbackOpenRate")) {
  console.error("Retention restraint validation failed — first magic moment must measure callback timing and open rate.");
  process.exit(1);
}

const recurrenceDensity = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/retention/recurrence-density.ts"),
  "utf8",
);
for (const event of RECURRENCE_DENSITY_EVENTS) {
  if (!recurrenceDensity.includes(event)) {
    console.error(`Retention restraint validation failed — missing recurrence-density event: ${event}`);
    process.exit(1);
  }
}
if (
  !recurrenceDensity.includes("pickRecurrenceDensityPrompt") ||
  !recurrenceDensity.includes("isRecurrenceDensityCopyAllowed") ||
  !recurrenceDensity.includes("analyzeRecurrenceDensitySignals")
) {
  console.error("Retention restraint validation failed — recurrence density must pick prompts and analyze signals.");
  process.exit(1);
}

const prompts = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/retention/gentle-return-prompts.ts"),
  "utf8",
);
const valueMoments = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/retention/archive-value-moments.ts"),
  "utf8",
);
const productCopy = fs.readFileSync(path.join(ROOT, "packages/shared/lib/product-copy.ts"), "utf8");
const retentionCopy = `${prompts}\n${valueMoments}\n${productCopy}\n${recurrenceDensity}`;
for (const line of REQUIRED_COPY) {
  if (!retentionCopy.includes(line)) {
    console.error(`Retention restraint validation failed — missing copy: "${line}"`);
    process.exit(1);
  }
}

if (!prompts.includes("isGentlePromptCopyAllowed") || !prompts.includes("BLOCKED_TERMS")) {
  console.error("Retention restraint validation failed — gentle prompts must filter forbidden copy.");
  process.exit(1);
}

const attachment = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/retention/archive-attachment-signals.ts"),
  "utf8",
);
if (attachment.includes("attachmentScore") && attachment.match(/user|UI|display/i)) {
  console.error("Retention restraint validation failed — do not expose attachment scores in UI paths.");
  process.exit(1);
}

function scanFile(relPath) {
  const full = path.join(ROOT, relPath);
  if (!fs.existsSync(full)) return;
  const lines = fs.readFileSync(full, "utf8").split("\n");
  for (const line of lines) {
    if (line.includes("FORBIDDEN_RE") || line.includes("isGentlePromptCopyAllowed") || line.includes("isRecurrenceDensityCopyAllowed") || line.includes("BLOCKED_TERMS")) continue;
    for (const { re, label } of FORBIDDEN_RE) {
      if (re.test(line)) {
        console.error(`Retention restraint validation failed — forbidden "${label}" in ${relPath}`);
        process.exit(1);
      }
    }
  }
}

for (const rel of USER_SCAN_DIRS) {
  const full = path.join(ROOT, rel);
  if (fs.statSync(full).isDirectory()) {
    for (const name of fs.readdirSync(full)) {
      scanFile(path.join(rel, name));
    }
  } else {
    scanFile(rel);
  }
}

const revisit = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/revisit/first-meaningful-revisit.ts"),
  "utf8",
);
if (!revisit.includes("pickStrongestReopenMoment")) {
  console.error("Retention restraint validation failed — meaningful revisit must use reopen payoff ranking.");
  process.exit(1);
}
if (revisit.includes("AI summary")) {
  console.error("Retention restraint validation failed — meaningful revisit must avoid AI summary framing.");
  process.exit(1);
}

console.log("Retention restraint validation passed.");
