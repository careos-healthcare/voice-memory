#!/usr/bin/env node
/**
 * Premium Polish Layer v1 — intentional archive motion and skeleton loading.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const required = [
  "packages/shared/lib/archive/archive-polish-motion.ts",
  "apps/web/components/archive/ArchiveSkeleton.tsx",
  "apps/web/components/archive/ArchiveLoadingState.tsx",
  "apps/web/components/archive/ArchiveEmptyState.tsx",
  "apps/web/components/archive/ArchiveTransition.tsx",
];

for (const rel of required) mustExist(rel);

const transition = read("apps/web/components/archive/ArchiveTransition.tsx");
for (const token of [
  "ArchiveTransition",
  "ArchiveAnimatedConfidence",
  "useReducedMotion",
  "framer-motion",
]) {
  if (!transition.includes(token)) fail(`ArchiveTransition missing ${token}`);
}

const skeleton = read("apps/web/components/archive/ArchiveSkeleton.tsx");
for (const variant of [
  "commandCenter",
  "timeline",
  "discoverFeed",
  "movement",
]) {
  if (!skeleton.includes(`"${variant}"`)) fail(`ArchiveSkeleton missing variant ${variant}`);
}

const loading = read("apps/web/components/archive/ArchiveLoadingState.tsx");
if (!loading.includes("ArchiveSkeleton")) fail("ArchiveLoadingState must use ArchiveSkeleton");
if (!/>\s*Loading[^<]*</.test(loading.replace(/sr-only[\s\S]*?<\/span>/g, ""))) {
  // ok — no visible Loading text
} else if (loading.match(/className=[^>]*>Loading/)) {
  fail("ArchiveLoadingState must not show visible Loading text");
}

const archiveSurfaces = [
  "apps/web/components/archive/EvidenceArchiveHome.tsx",
  "apps/web/components/archive/ArchiveCommandCenter.tsx",
  "apps/web/components/archive/ArchiveMovementCard.tsx",
  "apps/web/components/archive/ArchiveCard.tsx",
  "apps/web/components/archive/BeliefChangeTimeline.tsx",
  "apps/web/components/discover/TheoryChangeFeed.tsx",
];

for (const file of archiveSurfaces) {
  const src = read(file);
  if (/Loading changes/i.test(src)) fail(`${file} must not use raw "Loading changes"`);
  if (/>\s*Loading\.\.\./i.test(src) || /Loading archive/i.test(src)) {
    fail(`${file} must not use raw loading copy`);
  }
}

for (const [file, token] of [
  ["apps/web/components/archive/EvidenceArchiveHome.tsx", "ArchiveLoadingState"],
  ["apps/web/components/archive/ArchiveCommandCenter.tsx", "ArchiveLoadingState"],
  ["apps/web/components/archive/ArchiveCommandCenter.tsx", "ArchiveAnimatedConfidence"],
  ["apps/web/components/archive/ArchiveMovementCard.tsx", "ArchiveTransition"],
  ["apps/web/components/archive/ArchiveCard.tsx", "ArchiveTransition"],
  ["apps/web/components/archive/BeliefChangeTimeline.tsx", "ArchiveLoadingState"],
  ["apps/web/components/archive/BeliefChangeTimeline.tsx", "ArchiveTransition"],
  ["apps/web/components/discover/TheoryChangeFeed.tsx", "ArchiveLoadingState"],
]) {
  if (!read(file).includes(token)) fail(`${file} must use ${token}`);
}

const pkg = JSON.parse(read("package.json"));
}

if (failures.length) {
  console.error("validate-premium-polish failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-premium-polish ok");
