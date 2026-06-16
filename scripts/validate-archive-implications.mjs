#!/usr/bin/env node
/**
 * Archive Implications v1 — significance only, no advice/coaching/therapy.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const FORBIDDEN_OUTPUT = [
  /\byou should\b/i,
  /\byou need to\b/i,
  /\btry to\b/i,
  /\brecommend/i,
  /\badvice\b/i,
  /\bcoach/i,
  /\btherapy\b/i,
  /\btreatment\b/i,
  /\bhealing\b/i,
  /\bdiagnosis\b/i,
];

const IMPLICATION_FILES = [
  "lib/archive/archive-implications.ts",
  "lib/archive/archive-case-file-copy.ts",
  "lib/archive/archive-uniqueness-copy.ts",
  "lib/archive/archive-moat-proof.ts",
  "components/archive/ArchiveImplicationsCard.tsx",
  "components/archive/ArchiveUniquenessPanel.tsx",
  "components/archive/ArchiveMoatProof.tsx",
];

for (const rel of [
  "types/archive-implications.ts",
  ...IMPLICATION_FILES,
  "scripts/validate-archive-implications.mjs",
  "app/internal/archive-moat/page.tsx",
  "lib/internal/archive-moat-report.ts",
]) {
  mustExist(rel);
}

const engine = read("lib/archive/archive-implications.ts");
if (!engine.includes("buildArchiveImplications")) {
  fail("archive-implications missing buildArchiveImplications");
}
for (const dep of [
  "buildArchiveBeliefView",
  "buildBeliefSurvivalView",
  "buildArchiveReputationView",
  "buildArchiveAccuracyView",
  "buildContradictionHistoryView",
  "buildEvidenceArchiveStats",
]) {
  if (!engine.includes(dep)) fail(`implications engine must use ${dep}`);
}
if (/\bfetch\s*\(/.test(engine) || /\bopenai\b/i.test(engine)) {
  fail("archive-implications must not call LLM APIs");
}

for (const type of [
  "LONG_RUNNING",
  "STRENGTHENING",
  "WEAKENING",
  "LIFE_AREA_CONCENTRATION",
  "CROSS_AREA_PATTERN",
  "CONFLICTING_EVIDENCE",
  "PERSISTENT_PATTERN",
  "NEW_PATTERN",
]) {
  if (!engine.includes(type)) fail(`implications missing type ${type}`);
}

for (const rel of IMPLICATION_FILES) {
  const src = read(rel).replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
  for (const pattern of FORBIDDEN_OUTPUT) {
    if (pattern.test(src)) fail(`${rel} contains forbidden tone (${pattern})`);
  }
}

const card = read("components/archive/ArchiveImplicationsCard.tsx");
if (
  !card.includes("Why this matters") &&
  !card.includes("ARCHIVE_CASE_FILE_IMPLICATIONS_HEADLINE")
) {
  fail("ArchiveImplicationsCard missing headline");
}

const progressive = read("components/archive/ProgressiveArchiveHome.tsx");
if (!progressive.includes("ArchiveImplicationsCard")) {
  fail("ProgressiveArchiveHome must include ArchiveImplicationsCard");
}
if (
  !progressive.includes("Archive Case File") &&
  !progressive.includes("ARCHIVE_CASE_FILE_TITLE")
) {
  fail("ProgressiveArchiveHome must use Archive Case File framing");
}
if (/insight/i.test(progressive)) fail("ProgressiveArchiveHome must not use insight language");

const qCopy = read("lib/archive/archive-question-copy.ts");
if (!qCopy.includes("WHY_SHOULD_I_CARE")) fail("missing Why should I care question");

const qEngine = read("lib/archive/archive-question-engine.ts");
if (!qEngine.includes("buildArchiveImplications")) {
  fail("question engine must answer care from implications");
}
if (!qEngine.includes("IMPLICATIONS")) fail("question engine missing IMPLICATIONS answer");

const attachment = read("components/archive/ArchiveAttachmentPrompt.tsx");
if (!attachment.includes("archive-moat-perception-prompt")) {
  fail("attachment prompt must include moat perception phase");
}
if (
  !read("lib/archive/archive-attachment-copy.ts").includes(
    "If this archive disappeared tomorrow",
  )
) {
  fail("missing moat perception question copy");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:archive-implications"]) {
  fail("package.json missing validate:archive-implications");
}

if (failures.length) {
  console.error("validate-archive-implications failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-implications ok");
