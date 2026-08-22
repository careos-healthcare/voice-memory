#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "packages/shared/lib/transcript/transcript-cleanup.ts",
  "packages/shared/types/transcript-cleanup.ts",
  "packages/shared/lib/debug/transcript-cleanup-review.ts",
  "apps/web/components/internal/TranscriptCleanupDebugPanel.tsx",
  "apps/web/app/internal/transcript-cleanup/page.tsx",
  "packages/shared/types/journal.ts",
  "packages/shared/lib/patterns/phrase-memory.ts",
];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Transcript cleanup validation failed — missing ${rel}`);
    process.exit(1);
  }
}

const cleanup = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/transcript/transcript-cleanup.ts"),
  "utf8",
);
const journal = fs.readFileSync(path.join(ROOT, "packages/shared/types/journal.ts"), "utf8");
const phraseMemory = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/patterns/phrase-memory.ts"),
  "utf8",
);
const packageJson = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");

const CORE_EXPORTS = [
  "cleanupTranscript",
  "prepareTranscriptForSave",
  "transcriptForPhraseScanning",
  "trackTranscriptCleanupEvents",
  "TRANSCRIPT_CLEANUP_EVENTS",
];

for (const name of CORE_EXPORTS) {
  if (!cleanup.includes(name)) {
    console.error(`Transcript cleanup validation failed — missing export ${name}`);
    process.exit(1);
  }
}

if (!journal.includes("rawTranscript")) {
  console.error("Transcript cleanup validation failed — JournalEntry missing rawTranscript.");
  process.exit(1);
}

if (!journal.includes("transcriptCleanup")) {
  console.error("Transcript cleanup validation failed — JournalEntry missing transcriptCleanup.");
  process.exit(1);
}

if (!phraseMemory.includes("transcriptForPhraseScanning")) {
  console.error(
    "Transcript cleanup validation failed — phrase memory not wired to preserved phrase scanning.",
  );
  process.exit(1);
}

const bannedPatterns = [
  /\bsummarize\b/i,
  /\bhealing journey\b/i,
  /\btherapy\b/i,
  /\bcoaching\b/i,
  /\bself-care\b/i,
  /\bunpack this\b/i,
  /\bprocess your feelings\b/i,
];

for (const pattern of bannedPatterns) {
  if (pattern.test(cleanup)) {
    console.error(
      `Transcript cleanup validation failed — banned language in cleanup module: ${pattern}`,
    );
    process.exit(1);
  }
}

if (!cleanup.includes("preservedPhrases")) {
  console.error("Transcript cleanup validation failed — missing preserved phrase output.");
  process.exit(1);
}

if (!packageJson.includes("validate:transcript-cleanup")) {
  console.error("Transcript cleanup validation failed — npm script not wired.");
  process.exit(1);
}

console.log("Transcript cleanup restraint validation passed.");
