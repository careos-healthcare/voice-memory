#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

const required = [
  "components/archive/ArchiveWorthStatement.tsx",
  "lib/archive/archive-worth.ts",
  "types/archive-worth.ts",
  "components/archive/EvidenceLocker.tsx",
  "lib/archive/evidence-locker.ts",
  "types/evidence-locker.ts",
  "components/archive/BeliefDossier.tsx",
  "lib/archive/belief-dossier.ts",
  "types/belief-dossier.ts",
  "components/archive/EvidenceSearch.tsx",
  "lib/archive/evidence-search.ts",
  "types/evidence-search.ts",
  "components/archive/ArchiveLossAversionPrompt.tsx",
  "lib/archive/archive-loss-prompt.ts",
  "lib/archive/archive-value-score.ts",
  "lib/archive/archive-export-preview.ts",
  "lib/archive/archive-export-attachment.ts",
  "apps/voicememory_mobile/lib/widgets/archive_worth_statement.dart",
  "apps/voicememory_mobile/lib/widgets/evidence_locker_compact.dart",
  "apps/voicememory_mobile/lib/widgets/belief_dossier_compact.dart",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

function mustInclude(fileRel, tokens) {
  const src = fs.readFileSync(path.join(ROOT, fileRel), "utf8");
  for (const token of tokens) {
    if (!src.includes(token)) fail(`${fileRel} missing: ${token}`);
  }
}

mustInclude("lib/archive/archive-worth.ts", [
  "Your archive would be hard to rebuild",
]);
mustInclude("lib/archive/belief-dossier.ts", [
  "BELIEF_DOSSIER_WHAT_WOULD_CHANGE_TITLE",
  "What would change this belief?",
]);
mustInclude("lib/archive/evidence-locker.ts", [
  "These are the pieces of evidence your archive would lose",
]);
mustInclude("components/archive/EvidenceLocker.tsx", ["Source reflection"]);
mustInclude("app/export/page.tsx", ["evidence trail"]);
mustInclude("components/archive/ArchiveExportPreview.tsx", ["What your export includes"]);
mustInclude("lib/archive/archive-loss-prompt.ts", [
  "archive_loss_prompt_seen",
  "MIN_REFLECTIONS = 5",
]);
mustInclude("components/archive/EvidenceSearch.tsx", ["Search your evidence"]);
mustInclude("lib/memory-export.ts", ["archiveAttachment"]);

const scoreSrc = fs.readFileSync(
  path.join(ROOT, "lib/archive/archive-value-score.ts"),
  "utf8",
);
if (scoreSrc.includes("export function") && /score.*100|0–100/.test(scoreSrc)) {
  /* ok */
} else {
  fail("archive-value-score must define 0-100 score");
}
for (const page of [
  "components/archive/EvidenceArchiveHome.tsx",
  "app/account/page.tsx",
  "app/export/page.tsx",
  "app/pricing/PricingPageClient.tsx",
]) {
  const src = fs.readFileSync(path.join(ROOT, page), "utf8");
  if (!src.includes("ArchiveWorthStatement")) {
    fail(`${page} must include ArchiveWorthStatement`);
  }
}
const beliefPage = fs.readFileSync(
  path.join(ROOT, "app/archive-belief/page.tsx"),
  "utf8",
);
if (!beliefPage.includes("EvidenceArchiveHome")) {
  fail("archive-belief page must render EvidenceArchiveHome");
}
const home = fs.readFileSync(
  path.join(ROOT, "components/archive/EvidenceArchiveHome.tsx"),
  "utf8",
);
for (const token of [
  "ArchiveWorthStatement",
  "EvidenceLocker",
  "BeliefDossier",
  "EvidenceSearch",
  "ArchiveLossAversionPrompt",
]) {
  if (!home.includes(token)) fail(`EvidenceArchiveHome missing ${token}`);
}

const mobile = fs.readFileSync(
  path.join(ROOT, "apps/voicememory_mobile/lib/screens/archive_belief_screen.dart"),
  "utf8",
);
for (const token of [
  "ArchiveWorthStatement",
  "EvidenceLockerCompact",
  "BeliefDossierCompact",
  "ProtectArchiveBanner",
]) {
  if (!mobile.includes(token)) fail(`archive_belief_screen missing ${token}`);
}

const banned = ["therapist", "life coach", "insight engine", "you should try"];
for (const rel of [
  "components/archive/ArchiveWorthStatement.tsx",
  "components/archive/BeliefDossier.tsx",
  "components/archive/EvidenceLocker.tsx",
  "lib/archive/belief-dossier.ts",
]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8").toLowerCase();
  for (const phrase of banned) {
    if (src.includes(phrase)) fail(`${rel} contains banned phrase: ${phrase}`);
  }
}

const newAnalysisImports = [
  "openai",
  "theory-generation-v2",
  "new-analysis-engine",
];
for (const rel of [
  "lib/archive/evidence-locker.ts",
  "lib/archive/belief-dossier.ts",
  "lib/archive/archive-worth.ts",
]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  for (const imp of newAnalysisImports) {
    if (src.includes(imp)) fail(`${rel} must not import new analysis: ${imp}`);
  }
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:archive-value-deepening"]) {
  fail("package.json missing validate:archive-value-deepening");
}

const { runArchiveValueDeepeningTests } = await import(
  "../lib/reliability/archive-value-deepening-tests.ts"
);
const { failures: testFailures } = await runArchiveValueDeepeningTests();
for (const t of testFailures) fail(t);

if (failures.length) {
  console.error(
    "validate:archive-value-deepening failed:\n" + failures.map((f) => `  - ${f}`).join("\n"),
  );
  process.exit(1);
}

console.log("validate:archive-value-deepening OK");
