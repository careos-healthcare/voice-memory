#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

const required = [
  "packages/shared/types/archive-voice.ts",
  "packages/shared/lib/archive/archive-voice.ts",
  "packages/shared/lib/archive/archive-voice-scopes.ts",
  "packages/shared/lib/archive/archive-voice-report.ts",
  "apps/web/components/internal/ArchiveVoiceConsistencyPanel.tsx",
  "apps/web/app/internal/archive-voice/page.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const voice = fs.readFileSync(path.join(ROOT, "packages/shared/lib/archive/archive-voice.ts"), "utf8");
for (const phrase of [
  "Your archive is still evaluating",
  "New evidence may support",
  "This theory may be changing",
  "Recent reflections point",
  "Great job",
  "ARCHIVE_VOICE_FORBIDDEN",
]) {
  if (!voice.includes(phrase.split(" still")[0]) && phrase.includes("archive")) {
    if (!voice.includes("ARCHIVE_VOICE_PREFERRED")) fail("preferred list missing");
  }
}
if (!voice.includes("ARCHIVE_VOICE_PREFERRED")) fail("ARCHIVE_VOICE_PREFERRED missing");
if (!voice.includes("coaching")) fail("coaching category missing");
if (!voice.includes("motivational")) fail("motivational category missing");
if (!voice.includes("therapy")) fail("therapy category missing");

const panel = fs.readFileSync(
  path.join(ROOT, "apps/web/components/internal/ArchiveVoiceConsistencyPanel.tsx"),
  "utf8",
);
if (!panel.includes("report.title")) fail("panel must render report.title");

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:archive-voice")) fail("package.json missing script");

const { buildArchiveVoiceConsistencyReport } = await import(
  "../packages/shared/lib/archive/archive-voice-report.ts"
);
const { ARCHIVE_VOICE_SCOPES } = await import("../packages/shared/lib/archive/archive-voice-scopes.ts");
const { scanArchiveVoiceSource } = await import("../packages/shared/lib/archive/archive-voice.ts");

const report = buildArchiveVoiceConsistencyReport(ROOT);

if (report.title !== "Archive Voice Consistency") {
  fail("report title must be Archive Voice Consistency");
}

for (const scope of ARCHIVE_VOICE_SCOPES) {
  const result = report.scopes.find((s) => s.id === scope.id);
  if (!result) fail(`report missing scope ${scope.id}`);
  else if (result.filesScanned === 0) fail(`${scope.id} scanned zero files`);
}

const violations = report.scopes.flatMap((s) => s.violations);
for (const v of violations) {
  fail(`${v.category} @ ${v.file}:${v.line} — “${v.match}” (${v.excerpt.slice(0, 80)})`);
}

if (!report.pass) {
  fail(`archive voice audit failed with ${violations.length} violation(s)`);
}

const movementCopy = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/archive/archive-movement-copy.ts"),
  "utf8",
);
if (!movementCopy.includes("still evaluating")) {
  fail("archive-movement-copy should use preferred evaluating line");
}

const sample = scanArchiveVoiceSource(
  'disclaimer: "Not therapy, not a diagnosis."',
  "fixture.ts",
);
if (sample.length > 0) {
  fail("disclaimer line should be exempt from therapy scan");
}

if (failures.length > 0) {
  console.error("validate-archive-voice failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-archive-voice ok", {
  pass: report.pass,
  totalViolations: report.totalViolations,
  scopes: report.scopes.map((s) => ({
    id: s.id,
    files: s.filesScanned,
    violations: s.violations.length,
  })),
});
