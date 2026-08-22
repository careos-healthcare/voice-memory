#!/usr/bin/env node
/**
 * One-time migration helper: move kept debug routes to /internal, delete dead routes.
 * Safe to re-run: skips if app/internal exists and app/debug missing.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DEBUG_DIR = path.join(ROOT, "apps/web/app/debug");
const INTERNAL_DIR = path.join(ROOT, "apps/web/app/internal");

/** Required by product validators + founder hub. */
const KEEP_SLUGS = new Set([
  "onboarding-clarity",
  "vulnerability-timing",
  "resurfacing-variety",
  "behavior-truth",
  "reflection-friction",
  "mobile-readiness",
  "performance-health",
  "open-loop-performance",
  "open-loop-activation",
  "open-loops-readout",
  "resurfacing-confidence",
  "transcript-cleanup",
  "first-week-retention",
  "first-magic-moment",
  "recurrence-density",
  "silence-intelligence",
  "callback-learning",
  "resurfacing-timing",
  "sacredness-review",
  "archive-individuality",
  "archive-divergence",
  "emotional-integrity",
  "archive-simplicity",
  "durability-review",
  "founder-review",
  "retention-core",
  "entitlements",
]);

const SKIP_DIRS = new Set([
  ".next",
  "node_modules",
  ".git",
  "apps",
  "spp20",
  "project_textedit_export",
]);

function walk(dir, files = []) {
  if (!fs.existsSync(dir)) return files;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ent.isDirectory() && SKIP_DIRS.has(ent.name)) continue;
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, files);
    else if (/\.(tsx?|mjs|md|json)$/.test(ent.name)) files.push(p);
  }
  return files;
}

function replaceInTree(rootDir) {
  let count = 0;
  for (const file of walk(rootDir)) {
    let text = fs.readFileSync(file, "utf8");
    const next = text
      .replaceAll('"/internal/', '"/internal/')
      .replaceAll("'/internal/", "'/internal/")
      .replaceAll("href=\"/internal/", 'href="/internal/')
      .replaceAll("href='/internal/", "href='/internal/")
      .replaceAll("apps/web/app/internal/", "apps/web/app/internal/")
      .replaceAll('startsWith("/debug")', 'startsWith("/internal")');
    if (next !== text) {
      fs.writeFileSync(file, next);
      count++;
    }
  }
  return count;
}

if (!fs.existsSync(DEBUG_DIR)) {
  console.log("apps/web/app/debug not found — migration already applied or skipped.");
  process.exit(0);
}

fs.mkdirSync(INTERNAL_DIR, { recursive: true });

const slugs = fs
  .readdirSync(DEBUG_DIR, { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .map((d) => d.name);

let kept = 0;
let removed = 0;

for (const slug of slugs) {
  const src = path.join(DEBUG_DIR, slug);
  const dest = path.join(INTERNAL_DIR, slug);
  if (KEEP_SLUGS.has(slug)) {
    if (fs.existsSync(dest)) {
      fs.rmSync(dest, { recursive: true, force: true });
    }
    fs.renameSync(src, dest);
    kept++;
  } else {
    fs.rmSync(src, { recursive: true, force: true });
    removed++;
  }
}

if (fs.existsSync(DEBUG_DIR)) {
  const remaining = fs.readdirSync(DEBUG_DIR);
  if (remaining.length === 0) {
    fs.rmdirSync(DEBUG_DIR);
  }
}

const replaced = replaceInTree(INTERNAL_DIR);
console.log(`Kept ${kept} routes under app/internal/, removed ${removed}, updated ${replaced} files.`);
