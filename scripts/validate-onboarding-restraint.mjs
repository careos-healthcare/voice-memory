#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "packages/shared/types/onboarding-clarity.ts",
  "packages/shared/lib/onboarding/first-session-flow.ts",
  "packages/shared/lib/onboarding/confusion-signals.ts",
  "packages/shared/lib/onboarding/onboarding-observation.ts",
  "packages/shared/lib/onboarding/onboarding-copy.ts",
  "packages/shared/lib/onboarding/first-aha-callback.ts",
  "packages/shared/lib/onboarding/calm-comprehension.ts",
  "packages/shared/lib/onboarding/onboarding-restraint.ts",
  "packages/shared/lib/debug/onboarding-clarity.ts",
  "apps/web/components/onboarding/OnboardingNavigationTracker.tsx",
  "apps/web/components/onboarding/CalmComprehensionPrompt.tsx",
  "apps/web/components/debug/OnboardingClarityDebugPanel.tsx",
  "apps/web/app/internal/onboarding-clarity/page.tsx",
];

const REQUIRED_EVENTS = [
  "onboarding_completed",
  "first_aha_moment",
  "callback_surprise",
  "confusion_detected",
  "first_revisit_delay",
  "archive_understood",
  "overwhelmed_exit",
];

const REQUIRED_COPY = [
  "Your archive keeps track of what keeps repeating.",
  "This came back.", // via MEMORY_LANGUAGE / WEDGE_RESURFACING
  "Sign in only if you want encrypted backup across devices.",
  "A phrase you said before can show up again.",
  "Speak for about a minute. Your words stay on this device.",
  "Not therapy, not a diagnosis",
  "Your words stay yours",
  "Words you forgot you had already spoken.",
  "You used similar words before.",
  "Hearing your own voice makes the return harder to shrug off.",
];

const FORBIDDEN_RE = [
  { re: /\blife-changing\b/i, label: "life-changing" },
  { re: /\bAI-powered\b/i, label: "AI-powered" },
  { re: /\bself-improvement\b/i, label: "self-improvement" },
  { re: /\bself-awareness\b/i, label: "self-awareness" },
  { re: /\bproductivity\b/i, label: "productivity" },
  { re: /\breflective intelligence\b/i, label: "reflective intelligence" },
  { re: /\blongitudinal memory\b/i, label: "longitudinal memory" },
  { re: /\bemotional archive\b/i, label: "emotional archive" },
  { re: /\bmemory intelligence\b/i, label: "memory intelligence" },
  { re: /\bemotional continuity\b/i, label: "emotional continuity" },
  { re: /\bintelligence layer\b/i, label: "intelligence layer" },
  { re: /\bemotional chapter\b/i, label: "emotional chapter" },
  { re: /\breflective mirror\b/i, label: "reflective mirror" },
  { re: /\bgently return\b/i, label: "gently return" },
  { re: /\bdiscover patterns\b/i, label: "discover patterns" },
  { re: /\bmindfulness\b/i, label: "mindfulness" },
  { re: /\b(?:healing|growth|inner|self-care)\s+journey\b/i, label: "wellness journey" },
  { re: /\binsights summary\b/i, label: "insights summary" },
  { re: /\bcoaching\b/i, label: "coaching" },
  { re: /\bAI journal\b/i, label: "AI journal" },
];

const USER_SCAN = [
  "packages/shared/lib/onboarding/onboarding-copy.ts",
  "apps/web/components/onboarding",
  "apps/web/components/ActivationOnboarding.tsx",
  "apps/web/components/onboarding/ArchiveOnboarding.tsx",
  "packages/shared/lib/onboarding/archive-onboarding-copy.ts",
];

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Onboarding restraint validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const observation = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/onboarding/onboarding-observation.ts"),
  "utf8",
);
for (const event of REQUIRED_EVENTS) {
  if (!observation.includes(event)) {
    console.error(`Onboarding restraint validation failed — missing event: ${event}`);
    process.exit(1);
  }
}

const homeCopy = [
  fs.readFileSync(path.join(ROOT, "packages/shared/lib/onboarding/onboarding-copy.ts"), "utf8"),
  fs.readFileSync(path.join(ROOT, "packages/shared/lib/onboarding/archive-onboarding-copy.ts"), "utf8"),
  fs.readFileSync(path.join(ROOT, "packages/shared/lib/product-copy.ts"), "utf8"),
  fs.readFileSync(path.join(ROOT, "packages/shared/lib/trust-copy.ts"), "utf8"),
].join("\n");
const copyAlternatives = {
  "This came back.": ["MEMORY_LANGUAGE.thisCameBack", "WEDGE_RESURFACING.wordsCameBack"],
  "Your own words came back.": ["MEMORY_LANGUAGE.wordsReturned", "WEDGE_RESURFACING.pastWordsMatch"],
  "Your words stay yours": ["RECOGNITION_COPY.notAiJournal", "NOT_AI_JOURNAL_LINE"],
  "Speak for about a minute. Your words stay on this device.": [
    "ONBOARDING_RECORDER",
    "Tap to speak",
    "APP_DEVICE_LINE",
  ],
  "Sign in only if you want encrypted backup across devices.": [
    "signInPrompt",
    "ACCOUNT_BACKUP",
  ],
  "Not therapy, not a diagnosis": ["NOT_THERAPY", "product-clarity-copy", "TRUST"],
};
for (const line of REQUIRED_COPY) {
  const alts = copyAlternatives[line];
  if (alts ? !alts.some((token) => homeCopy.includes(token)) : !homeCopy.includes(line)) {
    console.error(`Onboarding restraint validation failed — missing onboarding copy: "${line}"`);
    process.exit(1);
  }
}

const calm = fs.readFileSync(path.join(ROOT, "packages/shared/lib/onboarding/calm-comprehension.ts"), "utf8");
if (!calm.includes("You don't need to organize anything here.")) {
  console.error("Onboarding restraint validation failed — missing calm comprehension copy.");
  process.exit(1);
}

const activation = fs.readFileSync(path.join(ROOT, "packages/shared/lib/activation-guidance.ts"), "utf8");
if (!activation.includes("ARCHIVE_ONBOARDING_SCREENS")) {
  console.error("Onboarding restraint validation failed — must use archive onboarding screens.");
  process.exit(1);
}

const archiveOnboarding = fs.readFileSync(
  path.join(ROOT, "apps/web/components/onboarding/ArchiveOnboarding.tsx"),
  "utf8",
);
if (
  !archiveOnboarding.includes("ARCHIVE_ONBOARDING_RECORD_CTA") &&
  !archiveOnboarding.includes("Record your first reflection")
) {
  console.error("Onboarding restraint validation failed — primary CTA must lead to recording.");
  process.exit(1);
}

const restraint = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/onboarding/onboarding-restraint.ts"),
  "utf8",
);
if (!restraint.includes("isOnboardingCopyAllowed") || !restraint.includes("ONBOARDING_BLOCKED_TERMS")) {
  console.error("Onboarding restraint validation failed — restraint helper required.");
  process.exit(1);
}

if (!restraint.includes("memory intelligence")) {
  console.error("Onboarding restraint validation failed — must block memory intelligence hype.");
  process.exit(1);
}

function scanFile(relPath) {
  const full = path.join(ROOT, relPath);
  if (!fs.existsSync(full)) return;
  if (relPath.includes("onboarding-restraint")) return;
  const lines = fs.readFileSync(full, "utf8").split("\n");
  for (const line of lines) {
    if (line.includes("FORBIDDEN_RE") || line.includes("ONBOARDING_BLOCKED")) continue;
    if (/\bnot an ai journal\b/i.test(line)) continue;
    for (const { re, label } of FORBIDDEN_RE) {
      if (re.test(line)) {
        if (label === "AI journal" && /\bnot an ai journal\b/i.test(line)) continue;
        console.error(`Onboarding restraint validation failed — forbidden "${label}" in ${relPath}`);
        process.exit(1);
      }
    }
  }
}

for (const rel of USER_SCAN) {
  const full = path.join(ROOT, rel);
  if (!fs.existsSync(full)) continue;
  if (fs.statSync(full).isDirectory()) {
    for (const name of fs.readdirSync(full)) {
      scanFile(path.join(rel, name));
    }
  } else {
    scanFile(rel);
  }
}

if (!fs.readFileSync(path.join(ROOT, "apps/web/app/providers.tsx"), "utf8").includes("OnboardingNavigationTracker")) {
  console.error("Onboarding restraint validation failed — wire OnboardingNavigationTracker in providers.");
  process.exit(1);
}

console.log("Onboarding restraint validation passed.");
