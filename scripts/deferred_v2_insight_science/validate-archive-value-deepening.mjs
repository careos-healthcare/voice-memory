#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const failures = [];
const fail = (msg) => failures.push(msg);

const required = [
  "apps/web/components/archive/ArchiveWorthStatement.tsx",
  "packages/shared/lib/archive/archive-worth.ts",
  "packages/shared/types/archive-worth.ts",
  "apps/web/components/archive/EvidenceLocker.tsx",
  "packages/shared/lib/archive/evidence-locker.ts",
  "packages/shared/types/evidence-locker.ts",
  "apps/web/components/archive/BeliefDossier.tsx",
  "packages/shared/lib/archive/belief-dossier.ts",
  "packages/shared/types/belief-dossier.ts",
  "apps/web/components/archive/EvidenceSearch.tsx",
  "packages/shared/lib/archive/evidence-search.ts",
  "packages/shared/types/evidence-search.ts",
  "apps/web/components/archive/ArchiveLossAversionPrompt.tsx",
  "packages/shared/lib/archive/archive-loss-prompt.ts",
  "packages/shared/lib/archive/archive-value-score.ts",
  "packages/shared/lib/archive/archive-export-preview.ts",
  "packages/shared/lib/archive/archive-export-attachment.ts",
  "apps/mobile/lib/widgets/archive_worth_statement.dart",
  "apps/mobile/lib/widgets/evidence_locker_compact.dart",
  "apps/mobile/lib/widgets/belief_dossier_compact.dart",
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

mustInclude("packages/shared/lib/archive/archive-worth.ts", [
  "Your archive would be hard to rebuild",
]);
mustInclude("packages/shared/lib/archive/belief-dossier.ts", [
  "BELIEF_DOSSIER_WHAT_WOULD_CHANGE_TITLE",
  "What would change this belief?",
]);
mustInclude("packages/shared/lib/archive/evidence-locker.ts", [
  "These are the pieces of evidence your archive would lose",
]);
mustInclude("apps/web/components/archive/EvidenceLocker.tsx", ["Source reflection"]);
mustInclude("apps/web/app/export/page.tsx", ["evidence trail"]);
mustInclude("apps/web/components/archive/ArchiveExportPreview.tsx", ["What your export includes"]);
mustInclude("packages/shared/lib/archive/archive-loss-prompt.ts", [
  "archive_loss_prompt_seen",
  "MIN_REFLECTIONS = 5",
]);
mustInclude("apps/web/components/archive/EvidenceSearch.tsx", ["Search your evidence"]);
mustInclude("packages/shared/lib/memory-export.ts", ["archiveAttachment"]);

const scoreSrc = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/archive/archive-value-score.ts"),
  "utf8",
);
if (scoreSrc.includes("export function") && /score.*100|0–100/.test(scoreSrc)) {
  /* ok */
} else {
  fail("archive-value-score must define 0-100 score");
}
for (const page of [
  "apps/web/components/archive/EvidenceArchiveHome.tsx",
  "apps/web/app/account/page.tsx",
  "apps/web/app/export/page.tsx",
  "apps/web/app/pricing/PricingPageClient.tsx",
]) {
  const src = fs.readFileSync(path.join(ROOT, page), "utf8");
  if (!src.includes("ArchiveWorthStatement")) {
    fail(`${page} must include ArchiveWorthStatement`);
  }
}
const beliefPage = fs.readFileSync(
  path.join(ROOT, "apps/web/app/archive-belief/page.tsx"),
  "utf8",
);
if (!beliefPage.includes("EvidenceArchiveHome")) {
  fail("archive-belief page must render EvidenceArchiveHome");
}
const home = fs.readFileSync(
  path.join(ROOT, "apps/web/components/archive/EvidenceArchiveHome.tsx"),
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
  path.join(ROOT, "apps/mobile/lib/screens/archive_belief_screen.dart"),
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
  "apps/web/components/archive/ArchiveWorthStatement.tsx",
  "apps/web/components/archive/BeliefDossier.tsx",
  "apps/web/components/archive/EvidenceLocker.tsx",
  "packages/shared/lib/archive/belief-dossier.ts",
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
  "packages/shared/lib/archive/evidence-locker.ts",
  "packages/shared/lib/archive/belief-dossier.ts",
  "packages/shared/lib/archive/archive-worth.ts",
]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  for (const imp of newAnalysisImports) {
    if (src.includes(imp)) fail(`${rel} must not import new analysis: ${imp}`);
  }
}

const { runArchiveValueDeepeningTests } = await import(
  "../../packages/shared/lib/reliability/archive-value-deepening-tests.ts"
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
