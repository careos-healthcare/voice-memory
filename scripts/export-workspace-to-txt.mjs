#!/usr/bin/env node
/**
 * Exports the project workspace into exactly 3 plain-text files on ~/Desktop/upload1/.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, "..");
const OUTPUT_DIR = path.join(process.env.HOME ?? "", "Desktop", "upload1");

const EXCLUDED_DIR_NAMES = new Set([
  ".git",
  "node_modules",
  ".dart_tool",
  "build",
  ".gradle",
  ".symlinks",
]);

const BINARY_OR_MEDIA_EXTENSIONS = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".ico",
  ".bmp",
  ".tiff",
  ".tif",
  ".mp3",
  ".wav",
  ".m4a",
  ".aac",
  ".ogg",
  ".flac",
  ".mp4",
  ".mov",
  ".avi",
  ".mkv",
  ".webm",
  ".pdf",
  ".zip",
  ".gz",
  ".tar",
  ".bz2",
  ".xz",
  ".7z",
  ".rar",
  ".woff",
  ".woff2",
  ".ttf",
  ".otf",
  ".eot",
  ".bin",
  ".exe",
  ".dll",
  ".so",
  ".dylib",
  ".class",
  ".jar",
  ".aar",
  ".apk",
  ".ipa",
  ".xcarchive",
  ".keystore",
  ".jks",
  ".DS_Store",
]);

function shouldExcludeDir(relativeDir) {
  const normalized = relativeDir.split(path.sep).filter(Boolean);
  for (const segment of normalized) {
    if (EXCLUDED_DIR_NAMES.has(segment)) return true;
  }
  const joined = normalized.join(path.sep);
  if (
    joined === "ios/Pods" ||
    joined.startsWith(`ios${path.sep}Pods${path.sep}`)
  ) {
    return true;
  }
  if (
    joined === path.join("android", ".gradle") ||
    joined.startsWith(`${path.join("android", ".gradle")}${path.sep}`)
  ) {
    return true;
  }
  return false;
}

function isExcludedFile(relativePath) {
  const ext = path.extname(relativePath).toLowerCase();
  if (BINARY_OR_MEDIA_EXTENSIONS.has(ext)) return true;
  const base = path.basename(relativePath);
  if (base === ".DS_Store") return true;
  return false;
}

function looksBinary(buffer) {
  if (buffer.length === 0) return false;
  const sample = buffer.subarray(0, Math.min(buffer.length, 8192));
  let nonText = 0;
  for (const byte of sample) {
    if (byte === 0) return true;
    if (byte < 9 || (byte > 13 && byte < 32 && byte !== 27)) nonText++;
  }
  return nonText / sample.length > 0.3;
}

function walkFiles(dir, files = []) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return files;
  }

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relativePath = path.relative(PROJECT_ROOT, fullPath);

    if (entry.isDirectory()) {
      if (shouldExcludeDir(relativePath)) continue;
      walkFiles(fullPath, files);
      continue;
    }

    if (!entry.isFile()) continue;
    if (isExcludedFile(relativePath)) continue;
    files.push(fullPath);
  }

  return files;
}

function formatFileBlock(relativePath, content) {
  return `### File: ${relativePath.replace(/\\/g, "/")}\n${content}\n\n`;
}

function splitIntoThree(chunks) {
  const totalChars = chunks.reduce((sum, c) => sum + c.length, 0);
  const target = Math.ceil(totalChars / 3);
  const parts = ["", "", ""];
  let partIndex = 0;
  let partSize = 0;

  for (const chunk of chunks) {
    if (
      partIndex < 2 &&
      partSize >= target &&
      partSize + chunk.length > target
    ) {
      partIndex++;
      partSize = 0;
    }
    parts[partIndex] += chunk;
    partSize += chunk.length;
  }

  return parts;
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(2)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const allFiles = walkFiles(PROJECT_ROOT).sort();
  const chunks = [];
  let processed = 0;
  let skippedBinary = 0;
  let skippedReadError = 0;

  for (const fullPath of allFiles) {
    const relativePath = path.relative(PROJECT_ROOT, fullPath);
    let buffer;
    try {
      buffer = fs.readFileSync(fullPath);
    } catch {
      skippedReadError++;
      continue;
    }

    if (looksBinary(buffer)) {
      skippedBinary++;
      continue;
    }

    let content;
    try {
      content = buffer.toString("utf8");
    } catch {
      skippedBinary++;
      continue;
    }

    if (content.includes("\u0000")) {
      skippedBinary++;
      continue;
    }

    chunks.push(formatFileBlock(relativePath, content));
    processed++;
  }

  const parts = splitIntoThree(chunks);
  const outputNames = [
    "archiveme_export_1.txt",
    "archiveme_export_2.txt",
    "archiveme_export_3.txt",
  ];

  const sizes = [];
  for (let i = 0; i < 3; i++) {
    const outPath = path.join(OUTPUT_DIR, outputNames[i]);
    fs.writeFileSync(outPath, parts[i], "utf8");
    sizes.push(fs.statSync(outPath).size);
  }

  console.log("=== Workspace Export Summary ===");
  console.log(`Project root: ${PROJECT_ROOT}`);
  console.log(`Output directory: ${OUTPUT_DIR}`);
  console.log(`Candidate files scanned: ${allFiles.length}`);
  console.log(`Files exported: ${processed}`);
  console.log(`Skipped (binary/heuristic): ${skippedBinary}`);
  console.log(`Skipped (read errors): ${skippedReadError}`);
  console.log("");
  for (let i = 0; i < 3; i++) {
    const outPath = path.join(OUTPUT_DIR, outputNames[i]);
    const exists = fs.existsSync(outPath);
    console.log(
      `${outputNames[i]}: ${exists ? "created" : "MISSING"} — ${formatBytes(sizes[i])} (${sizes[i]} bytes)`,
    );
  }
  console.log("");
  console.log(
    `Total export size: ${formatBytes(sizes.reduce((a, b) => a + b, 0))}`,
  );
}

main();
