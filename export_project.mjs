#!/usr/bin/env node
/**
 * Pack the full repository into 3 plain-text export files on ~/Desktop/upload1/.
 *
 * Usage: node export_project.mjs
 */

import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import os from "node:os";

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname));
const OUT_DIR = path.join(os.homedir(), "Desktop", "upload1");
const OUT_FILES = [
  path.join(OUT_DIR, "project_export_1.txt"),
  path.join(OUT_DIR, "project_export_2.txt"),
  path.join(OUT_DIR, "project_export_3.txt"),
];

/** Directory names skipped entirely during walk. */
const EXCLUDE_DIR_NAMES = new Set([
  ".git",
  "node_modules",
  ".dart_tool",
  "build",
  "Pods",
  ".gradle",
  ".next",
  ".turbo",
  "coverage",
  "dist",
]);

/** Path fragments that exclude a file even if encountered outside pruned dirs. */
const EXCLUDE_PATH_FRAGMENTS = [
  "/.git/",
  "/node_modules/",
  "/.dart_tool/",
  "/build/",
  "/ios/Pods/",
  "/android/.gradle/",
  "/.next/",
  "/.turbo/",
  "/coverage/",
  "/dist/",
];

/** Known binary / media extensions (lowercase, with leading dot). */
const BINARY_EXTENSIONS = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".ico",
  ".bmp",
  ".tif",
  ".tiff",
  ".heic",
  ".heif",
  ".pdf",
  ".zip",
  ".gz",
  ".tar",
  ".bz2",
  ".7z",
  ".rar",
  ".jar",
  ".aar",
  ".apk",
  ".aab",
  ".ipa",
  ".exe",
  ".dll",
  ".so",
  ".dylib",
  ".wasm",
  ".woff",
  ".woff2",
  ".ttf",
  ".otf",
  ".eot",
  ".mp3",
  ".mp4",
  ".m4a",
  ".mov",
  ".avi",
  ".mkv",
  ".flac",
  ".wav",
  ".aac",
  ".ogg",
  ".webm",
  ".DS_Store",
  ".tsbuildinfo",
  ".bin",
  ".dat",
  ".pem",
  ".p12",
  ".keystore",
  ".jks",
  ".xcarchive",
  ".class",
  ".pyc",
  ".pyo",
  ".pickle",
  ".sqlite",
  ".db",
  ".lockb",
]);

const MAX_FILE_BYTES = 2 * 1024 * 1024;

function shouldExcludeRelative(relPosix) {
  return EXCLUDE_PATH_FRAGMENTS.some((frag) => relPosix.includes(frag));
}

function isBinaryCandidate(fileName) {
  const ext = path.extname(fileName).toLowerCase();
  return BINARY_EXTENSIONS.has(ext);
}

async function looksBinary(fullPath) {
  const handle = await fsp.open(fullPath, "r");
  try {
    const buf = Buffer.alloc(8192);
    const { bytesRead } = await handle.read(buf, 0, buf.length, 0);
    return buf.subarray(0, bytesRead).includes(0);
  } finally {
    await handle.close();
  }
}

async function readFileContents(fullPath) {
  const stat = await fsp.stat(fullPath);
  if (stat.size > MAX_FILE_BYTES) {
    return `[SKIPPED: file exceeds ${MAX_FILE_BYTES} bytes]\n`;
  }
  try {
    const data = await fsp.readFile(fullPath);
    if (data.includes(0)) return null;
    return data.toString("utf8");
  } catch {
    try {
      const data = await fsp.readFile(fullPath);
      return data.toString("latin1");
    } catch (err) {
      return `[ERROR reading file: ${err.message}]\n`;
    }
  }
}

async function collectFiles(dir, relBase = "") {
  /** @type {{ rel: string, full: string, size: number }[]} */
  const out = [];
  let entries;
  try {
    entries = await fsp.readdir(dir, { withFileTypes: true });
  } catch {
    return out;
  }

  entries.sort((a, b) => a.name.localeCompare(b.name));

  for (const entry of entries) {
    const rel = relBase ? `${relBase}/${entry.name}` : entry.name;
    const full = path.join(dir, entry.name);
    const relPosix = rel.split(path.sep).join("/");

    if (entry.isDirectory()) {
      if (EXCLUDE_DIR_NAMES.has(entry.name)) continue;
      if (shouldExcludeRelative(`/${relPosix}/`)) continue;
      out.push(...(await collectFiles(full, relPosix)));
      continue;
    }

    if (!entry.isFile()) continue;
    if (shouldExcludeRelative(`/${relPosix}`)) continue;
    if (isBinaryCandidate(entry.name)) continue;
    if (await looksBinary(full)) continue;

    let size = 0;
    try {
      size = (await fsp.stat(full)).size;
    } catch {
      size = 0;
    }
    out.push({ rel: relPosix, full, size });
  }

  return out;
}

function formatBlock(rel, contents) {
  return `### File: ${rel}\n\n${contents}\n\n`;
}

async function main() {
  await fsp.mkdir(OUT_DIR, { recursive: true });

  const files = await collectFiles(ROOT);
  files.sort((a, b) => a.rel.localeCompare(b.rel));

  /** @type {{ rel: string, full: string }[][]} */
  const buckets = [[], [], []];
  const bucketSizes = [0, 0, 0];

  for (const file of files) {
    const idx = bucketSizes.indexOf(Math.min(...bucketSizes));
    buckets[idx].push(file);
    bucketSizes[idx] += Math.max(file.size, 1);
  }

  console.log(`Collected ${files.length} text-readable files`);
  console.log(
    `Bucket targets (bytes): ${bucketSizes.map((n) => n.toLocaleString()).join(", ")}`,
  );

  for (let i = 0; i < 3; i++) {
    const parts = [
      `# project_export_${i + 1}.txt`,
      `# Repository: ${ROOT}`,
      `# Files in this volume: ${buckets[i].length}`,
      `# Generated: ${new Date().toISOString()}`,
      "",
    ];

    for (const { rel, full } of buckets[i]) {
      const contents = await readFileContents(full);
      if (contents == null) continue;
      parts.push(formatBlock(rel, contents));
    }

    await fsp.writeFile(OUT_FILES[i], parts.join("\n"), "utf8");
    const stat = await fsp.stat(OUT_FILES[i]);
    console.log(
      `Wrote ${OUT_FILES[i]} (${stat.size.toLocaleString()} bytes, ${buckets[i].length} files)`,
    );
  }

  const manifest = [
    `# Export manifest`,
    `generated_at: ${new Date().toISOString()}`,
    `root: ${ROOT}`,
    `total_files: ${files.length}`,
    `out_dir: ${OUT_DIR}`,
    "",
    ...OUT_FILES.map((f, i) => `${path.basename(f)}: ${buckets[i].length} files`),
    "",
    "files:",
    ...files.map((f) => f.rel),
    "",
  ].join("\n");
  await fsp.writeFile(path.join(OUT_DIR, "export_manifest.txt"), manifest, "utf8");

  console.log(`Manifest: ${path.join(OUT_DIR, "export_manifest.txt")}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
