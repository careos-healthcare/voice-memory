#!/usr/bin/env node
/**
 * Distribution Engine v1 — repeatable acquisition without social network mechanics.
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

const REQUIRED = [
  "types/distribution.ts",
  "lib/distribution/transformation-moments.ts",
  "lib/distribution/testimonial-store.ts",
  "lib/distribution/archive-share-cards.ts",
  "lib/distribution/creator-story-builder.ts",
  "lib/distribution/share-archive-prompt.ts",
  "lib/distribution/proof-wall.ts",
  "lib/distribution/creator-kit.ts",
  "lib/distribution/distribution-metrics.ts",
  "lib/internal/distribution-report.ts",
  "components/distribution/ArchiveShareCard.tsx",
  "components/distribution/TestimonialCapturePrompt.tsx",
  "components/distribution/ShareArchivePrompt.tsx",
  "components/distribution/ProofWall.tsx",
  "components/distribution/DistributionArchivePanel.tsx",
  "app/internal/distribution/page.tsx",
  "app/creator-kit/page.tsx",
];

for (const rel of REQUIRED) mustExist(rel);

const moments = read("lib/distribution/transformation-moments.ts");
for (const type of [
  "first_belief",
  "belief_change",
  "belief_challenged",
  "archive_changed_while_away",
  "first_contradiction",
  "first_strong_attachment",
  "first_return_after_archive_change",
]) {
  if (!moments.includes(type)) fail(`transformation-moments missing ${type}`);
}
for (const fn of ["syncTransformationMoments", "readDistributionMoments"]) {
  if (!moments.includes(fn)) fail(`transformation-moments missing ${fn}`);
}

const shareCard = read("components/distribution/ArchiveShareCard.tsx");
for (const line of [
  "My archive changed its mind.",
  "screenshot",
]) {
  if (!shareCard.includes(line) && !read("lib/distribution/archive-share-cards.ts").includes(line)) {
    fail(`share card missing example line: ${line}`);
  }
}

const testimonial = read("lib/distribution/testimonial-store.ts");
if (!testimonial.includes("What surprised you most?")) {
  fail("testimonial capture must ask What surprised you most?");
}

const builder = read("lib/distribution/creator-story-builder.ts");
if (!builder.includes("CreatorStoryBuilder")) fail("missing CreatorStoryBuilder");
for (const fmt of ["forTikTok", "forInstagram", "forShorts"]) {
  if (!builder.includes(fmt)) fail(`CreatorStoryBuilder missing ${fmt}`);
}

const shareArchive = read("lib/distribution/share-archive-prompt.ts");
if (!shareArchive.includes("Share Archive")) fail("missing Share Archive label");
for (const trigger of [
  "belief_change",
  "first_strong_attachment",
  "archive_changed_while_away",
  "first_contradiction",
  "first_return_after_archive_change",
]) {
  if (!shareArchive.includes(trigger)) fail(`share-archive missing trigger ${trigger}`);
}

const proofWall = read("lib/distribution/proof-wall.ts");
if (!proofWall.includes("testimonial") || !proofWall.includes("archive_moment")) {
  fail("proof-wall must use real testimonials and archive moments");
}
if (proofWall.includes("fake") || proofWall.includes("thousands of users")) {
  fail("proof-wall must not use fake social proof");
}

const creatorKit = read("lib/distribution/creator-kit.ts");
if (!creatorKit.includes("KIT_SIZE = 10") && !creatorKit.includes("KIT_SIZE")) {
  fail("creator-kit must generate 10 items per section");
}

const metrics = read("lib/distribution/distribution-metrics.ts");
for (const rate of [
  "shareRate",
  "referralRate",
  "testimonialRate",
  "creatorStoryRate",
  "distributionScore",
]) {
  if (!metrics.includes(rate)) fail(`distribution-metrics missing ${rate}`);
}

const archiveHome = read("components/archive/EvidenceArchiveHome.tsx");
if (!archiveHome.includes("DistributionArchivePanel")) {
  fail("EvidenceArchiveHome must wire DistributionArchivePanel");
}

const homepage = read("app/page.tsx");
if (!homepage.includes("ProofWall")) {
  fail("homepage must use ProofWall");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:distribution-engine"]) {
  fail("package.json missing validate:distribution-engine");
}

if (failures.length) {
  console.error("validate-distribution-engine failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-distribution-engine ok");
