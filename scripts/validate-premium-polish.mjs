#!/usr/bin/env node
/**
 * Premium Polish Layer v1 — intentional archive motion and skeleton loading.
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

const required = [
  "lib/archive/archive-polish-motion.ts",
  "components/archive/ArchiveSkeleton.tsx",
  "components/archive/ArchiveLoadingState.tsx",
  "components/archive/ArchiveEmptyState.tsx",
  "components/archive/ArchiveTransition.tsx",
];

for (const rel of required) mustExist(rel);

const transition = read("components/archive/ArchiveTransition.tsx");
for (const token of [
  "ArchiveTransition",
  "ArchiveAnimatedConfidence",
  "useReducedMotion",
  "framer-motion",
]) {
  if (!transition.includes(token)) fail(`ArchiveTransition missing ${token}`);
}

const skeleton = read("components/archive/ArchiveSkeleton.tsx");
for (const variant of [
  "commandCenter",
  "timeline",
  "discoverFeed",
  "movement",
]) {
  if (!skeleton.includes(`"${variant}"`)) fail(`ArchiveSkeleton missing variant ${variant}`);
}

const loading = read("components/archive/ArchiveLoadingState.tsx");
if (!loading.includes("ArchiveSkeleton")) fail("ArchiveLoadingState must use ArchiveSkeleton");
if (!/>\s*Loading[^<]*</.test(loading.replace(/sr-only[\s\S]*?<\/span>/g, ""))) {
  // ok — no visible Loading text
} else if (loading.match(/className=[^>]*>Loading/)) {
  fail("ArchiveLoadingState must not show visible Loading text");
}

const archiveSurfaces = [
  "components/archive/EvidenceArchiveHome.tsx",
  "components/archive/ArchiveCommandCenter.tsx",
  "components/archive/ArchiveMovementCard.tsx",
  "components/archive/ArchiveCard.tsx",
  "components/archive/BeliefChangeTimeline.tsx",
  "components/discover/TheoryChangeFeed.tsx",
];

for (const file of archiveSurfaces) {
  const src = read(file);
  if (/Loading changes/i.test(src)) fail(`${file} must not use raw "Loading changes"`);
  if (/>\s*Loading\.\.\./i.test(src) || /Loading archive/i.test(src)) {
    fail(`${file} must not use raw loading copy`);
  }
}

for (const [file, token] of [
  ["components/archive/EvidenceArchiveHome.tsx", "ArchiveLoadingState"],
  ["components/archive/ArchiveCommandCenter.tsx", "ArchiveLoadingState"],
  ["components/archive/ArchiveCommandCenter.tsx", "ArchiveAnimatedConfidence"],
  ["components/archive/ArchiveMovementCard.tsx", "ArchiveTransition"],
  ["components/archive/ArchiveCard.tsx", "ArchiveTransition"],
  ["components/archive/BeliefChangeTimeline.tsx", "ArchiveLoadingState"],
  ["components/archive/BeliefChangeTimeline.tsx", "ArchiveTransition"],
  ["components/discover/TheoryChangeFeed.tsx", "ArchiveLoadingState"],
]) {
  if (!read(file).includes(token)) fail(`${file} must use ${token}`);
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:premium-polish"]) {
  fail("package.json missing validate:premium-polish");
}

if (failures.length) {
  console.error("validate-premium-polish failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-premium-polish ok");
