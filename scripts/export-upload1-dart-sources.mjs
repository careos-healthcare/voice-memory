#!/usr/bin/env node
/**
 * Export Dart + primary project source files into <=3 plain-text bundles on Desktop/upload1.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUTPUT_DIR = path.join(process.env.HOME ?? "/Users/chiragpatel", "Desktop", "upload1");
const MAX_OUTPUT_FILES = 3;
const MAX_FILE_BYTES = 2 * 1024 * 1024;

const EXCLUDED_DIR_NAMES = new Set([
  "node_modules",
  ".git",
  ".next",
  "build",
  ".dart_tool",
  ".turbo",
  "coverage",
  "Pods",
  "DerivedData",
  "test-results",
  "playwright-report",
  ".cursor",
  "out",
  "dist",
  ".cmake",
  "ephemeral",
  "third_party",
]);

const CODE_EXTENSIONS = new Set([
  ".dart",
  ".ts",
  ".tsx",
  ".mjs",
  ".sql",
  ".sh",
]);

const CONFIG_BASENAMES = new Set([
  "package.json",
  "pubspec.yaml",
  "tsconfig.json",
  "turbo.json",
  "docker-compose.yml",
  ".env.example",
]);

const SKIP_BASENAMES = new Set([
  "package-lock.json",
  "pubspec.lock",
]);

const BINARY_EXTENSIONS = new Set([
  ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".woff", ".woff2", ".ttf",
  ".mp3", ".wav", ".zip", ".pdf", ".bin", ".so", ".dylib", ".lockb",
]);

function shouldSkipDir(name) {
  return EXCLUDED_DIR_NAMES.has(name);
}

function isPrimarySource(rel) {
  const base = path.basename(rel);
  if (SKIP_BASENAMES.has(base)) return false;
  const ext = path.extname(rel).toLowerCase();
  if (BINARY_EXTENSIONS.has(ext)) return false;
  if (CODE_EXTENSIONS.has(ext)) return true;
  if (CONFIG_BASENAMES.has(base)) return true;
  if (base.startsWith("tsconfig.") && ext === ".json") return true;
  return false;
}

function collectFiles(dir, acc = []) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return acc;
  }

  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (shouldSkipDir(entry.name)) continue;
      if (entry.name.startsWith(".") && entry.name !== ".github") continue;
      collectFiles(full, acc);
      continue;
    }
    if (!entry.isFile()) continue;
    const rel = path.relative(ROOT, full).replace(/\\/g, "/");
    if (!isPrimarySource(rel)) continue;
    acc.push(full);
  }
  return acc;
}

function formatBlock(rel, content) {
  const header = `// File: ${rel}\n`;
  const footer = `\n// End: ${rel}\n\n${"=".repeat(80)}\n\n`;
  return header + content + footer;
}

function redact(content) {
  return content
    .replace(/sk_live_[A-Za-z0-9]+/g, "sk_live_[REDACTED]")
    .replace(/sk_test_[A-Za-z0-9]+/g, "sk_test_[REDACTED]")
    .replace(/(DATABASE_URL=)([^\n\r]+)/gi, "$1[REDACTED]")
    .replace(/(OPENAI_API_KEY=)([^\n\r]+)/gi, "$1[REDACTED]")
    .replace(/(RESEND_API_KEY=)([^\n\r]+)/gi, "$1[REDACTED]")
    .replace(/postgres:\/\/[^\s\n\r'"]+/gi, "postgres://[REDACTED]");
}

fs.mkdirSync(OUTPUT_DIR, { recursive: true });

const files = collectFiles(ROOT).sort((a, b) =>
  path.relative(ROOT, a).localeCompare(path.relative(ROOT, b)),
);

const entries = [];
let skippedLarge = 0;

for (const abs of files) {
  const rel = path.relative(ROOT, abs).replace(/\\/g, "/");
  let stat;
  try {
    stat = fs.statSync(abs);
  } catch {
    continue;
  }
  if (stat.size > MAX_FILE_BYTES) {
    skippedLarge += 1;
    entries.push({
      rel,
      bytes: 0,
      block: `// File: ${rel}\n// SKIPPED: file exceeds ${MAX_FILE_BYTES} bytes (${stat.size} bytes)\n\n${"=".repeat(80)}\n\n`,
    });
    continue;
  }
  let content;
  try {
    content = redact(fs.readFileSync(abs, "utf8"));
  } catch {
    entries.push({
      rel,
      bytes: 0,
      block: `// File: ${rel}\n// SKIPPED: unreadable as UTF-8 text\n\n${"=".repeat(80)}\n\n`,
    });
    continue;
  }
  const block = formatBlock(rel, content);
  entries.push({ rel, bytes: Buffer.byteLength(block, "utf8"), block });
}

const totalBytes = entries.reduce((sum, e) => sum + e.bytes, 0);
const targetPerFile = Math.ceil(totalBytes / MAX_OUTPUT_FILES);

const buckets = Array.from({ length: MAX_OUTPUT_FILES }, () => ({
  entries: [],
  bytes: 0,
}));

for (const entry of entries) {
  let idx = buckets.reduce(
    (minIdx, bucket, i, arr) => (bucket.bytes < arr[minIdx].bytes ? i : minIdx),
    0,
  );
  buckets[idx].entries.push(entry);
  buckets[idx].bytes += entry.bytes;
}

const manifest = {
  generatedAt: new Date().toISOString(),
  projectRoot: ROOT,
  outputDir: OUTPUT_DIR,
  totalSourceFiles: files.length,
  exportedEntries: entries.length,
  skippedLarge,
  totalBytes,
  outputFiles: [],
};

const outputPaths = [];

for (let i = 0; i < MAX_OUTPUT_FILES; i += 1) {
  const bucket = buckets[i];
  const outName = `project_dart_files_${i + 1}.txt`;
  const outPath = path.join(OUTPUT_DIR, outName);
  const header = [
    `# ArchiveMe source export — part ${i + 1} of ${MAX_OUTPUT_FILES}`,
    `# Generated: ${manifest.generatedAt}`,
    `# Files in this part: ${bucket.entries.length}`,
    `# Approx size: ${bucket.bytes} bytes`,
    "",
    "=".repeat(80),
    "",
  ].join("\n");
  const body = bucket.entries.map((e) => e.block).join("");
  fs.writeFileSync(outPath, header + body, "utf8");
  outputPaths.push(outPath);
  manifest.outputFiles.push({
    name: outName,
    path: outPath,
    fileCount: bucket.entries.length,
    bytes: bucket.bytes,
  });
}

const manifestPath = path.join(OUTPUT_DIR, "export_manifest.json");
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2), "utf8");

console.log(JSON.stringify(manifest, null, 2));
