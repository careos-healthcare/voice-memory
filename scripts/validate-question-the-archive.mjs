#!/usr/bin/env node
/**
 * Question The Archive v1 — structured interrogation, not chat.
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

const FORBIDDEN_UI = [
  /\bopenai\b/i,
  /\bchatgpt\b/i,
  /\bllm\b/i,
  /\bgpt\b/i,
  /assistant\s*prompt/i,
  /<textarea/i,
  /type\s*=\s*["']text["']/i,
  /free[\s-]*form/i,
  /conversation\s*ui/i,
];

for (const rel of [
  "types/archive-question.ts",
  "lib/archive/archive-question-engine.ts",
  "lib/archive/archive-question-copy.ts",
  "components/archive/QuestionTheArchive.tsx",
  "components/archive/ArchiveQuestionAnswerCard.tsx",
]) {
  mustExist(rel);
}

const engine = read("lib/archive/archive-question-engine.ts");
if (!engine.includes("buildArchiveQuestionAnswers")) {
  fail("archive-question-engine missing buildArchiveQuestionAnswers");
}
for (const dep of [
  "buildArchiveBeliefView",
  "buildBeliefSurvivalView",
  "buildArchiveReputationView",
  "buildArchiveAccuracyView",
  "buildContradictionHistoryView",
]) {
  if (!engine.includes(dep)) fail(`engine must use ${dep}`);
}
if (/\bfetch\s*\(/.test(engine) || /\bopenai\b/i.test(engine)) {
  fail("archive-question-engine must not call LLM APIs");
}

for (const key of [
  "WHY",
  "SUPPORTING_EVIDENCE",
  "CONTRADICTING_EVIDENCE",
  "FIRST_APPEARED",
  "STRENGTH_DIRECTION",
  "WHAT_CHANGES_THIS",
  "RECENT_CHANGES",
  "RELIABILITY",
  "LIFE_AREAS",
  "STRONGEST_EVIDENCE",
  "IMPLICATIONS",
]) {
  if (!engine.includes(key)) fail(`engine missing answer key ${key}`);
}
if (!engine.includes("buildArchiveImplications")) {
  fail("engine must use buildArchiveImplications for WHY_SHOULD_I_CARE");
}

const types = read("types/archive-question.ts");
for (const q of [
  "WHY",
  "SHOW_EVIDENCE",
  "SHOW_CONTRADICTIONS",
  "WHEN_DID_THIS_START",
  "IS_IT_GETTING_STRONGER",
  "WHAT_WOULD_CHANGE_IT",
  "WHAT_CHANGED_RECENTLY",
  "HOW_RELIABLE_IS_IT",
  "WHERE_DOES_THIS_APPEAR",
  "STRONGEST_EVIDENCE",
  "WHY_SHOULD_I_CARE",
]) {
  if (!types.includes(q)) fail(`types missing question ${q}`);
}

const card = read("components/archive/ArchiveQuestionAnswerCard.tsx");
for (const label of ["Question", "Archive answer", "Evidence"]) {
  if (!card.includes(label)) fail(`answer card missing label ${label}`);
}
if (card.includes("recommend") || card.includes("therapy")) {
  fail("answer card must not include coaching or therapy framing");
}

const qta = read("components/archive/QuestionTheArchive.tsx");
if (
  !qta.includes("Question the Archive") &&
  !qta.includes("QUESTION_THE_ARCHIVE_HEADLINE")
) {
  fail("missing headline");
}
if (!qta.includes('type="button"')) fail("questions must be buttons not chat input");

const copy = read("lib/archive/archive-question-copy.ts");
if (copy.includes("Archive reputation") || copy.includes("Archive Reputation")) {
  fail("public copy must hide reputation mechanics");
}
for (const band of ["Low", "Developing", "Strong"]) {
  if (!copy.includes(band)) fail(`copy missing trust band ${band}`);
}

const progressive = read("components/archive/ProgressiveArchiveHome.tsx");
if (!progressive.includes("QuestionTheArchive")) {
  fail("ProgressiveArchiveHome must include QuestionTheArchive");
}
if (!progressive.includes("ArchiveImplicationsCard")) {
  fail("ProgressiveArchiveHome must include ArchiveImplicationsCard");
}

const mobile = read("apps/voicememory_mobile/lib/widgets/question_the_archive_mobile.dart");
const mobileEngine = read(
  "apps/voicememory_mobile/lib/features/archive_question/archive_question_engine.dart",
);
if (
  !mobile.includes("Question the Archive") &&
  !mobile.includes("ArchiveQuestionEngine.headline") &&
  !mobileEngine.includes("Question the Archive")
) {
  fail("mobile widget missing Question the Archive");
}

for (const rel of [
  "components/archive/QuestionTheArchive.tsx",
  "components/archive/ArchiveQuestionAnswerCard.tsx",
]) {
  const src = read(rel);
  for (const pattern of FORBIDDEN_UI) {
    if (pattern.test(src)) fail(`${rel} must not include chat/assistant UI (${pattern})`);
  }
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:question-the-archive"]) {
  fail("package.json missing validate:question-the-archive");
}

if (failures.length) {
  console.error("validate-question-the-archive failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-question-the-archive ok");
