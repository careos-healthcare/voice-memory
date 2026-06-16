#!/usr/bin/env node
/**
 * Archive onboarding rewrite — five headline-only screens.
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

const HEADLINES = [
  "Your archive keeps track of what keeps repeating.",
  "Every reflection becomes evidence.",
  "Over time your archive forms beliefs.",
  "Those beliefs strengthen, weaken, or disappear.",
  "Record your first reflection.",
];

const required = [
  "lib/onboarding/archive-onboarding-copy.ts",
  "components/onboarding/ArchiveOnboarding.tsx",
  "components/ActivationOnboarding.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = read("lib/onboarding/archive-onboarding-copy.ts");
for (const headline of HEADLINES) {
  if (!copy.includes(headline)) fail(`archive-onboarding-copy missing: ${headline}`);
}
if (!copy.includes("ARCHIVE_ONBOARDING_SCREEN_COUNT")) {
  fail("archive-onboarding-copy must export screen count");
}

const onboarding = read("components/onboarding/ArchiveOnboarding.tsx");
if (!onboarding.includes("ARCHIVE_ONBOARDING_SCREENS")) {
  fail("ArchiveOnboarding must use ARCHIVE_ONBOARDING_SCREENS");
}
if (!onboarding.includes("archive-onboarding-record-cta")) {
  fail("ArchiveOnboarding must expose record CTA test id");
}
if (
  !onboarding.includes("ARCHIVE_ONBOARDING_RECORD_CTA") &&
  !onboarding.includes("Record your first reflection")
) {
  fail("ArchiveOnboarding final CTA must match screen 5");
}

const forbiddenInOnboarding = [
  "WhatThisArchiveCanAnswer",
  "ACTIVATION_EVOLVING_VIEW",
  "ACTIVATION_LEAD",
  "ACTIVATION_QUIET_EARLY",
  "ACTIVATION_WHY_RETURN",
  "stepBackup",
  "Sign in only if you want",
  "transcribe",
  "/demo",
  "dashboard",
  "Discover",
  "theory tracker",
  "blind spot",
  "evidence locker",
  "command center",
];
for (const token of forbiddenInOnboarding) {
  if (onboarding.includes(token)) fail(`ArchiveOnboarding must not include: ${token}`);
}

const activation = read("components/ActivationOnboarding.tsx");
if (!activation.includes("ArchiveOnboarding")) {
  fail("ActivationOnboarding must re-export ArchiveOnboarding");
}

const guidance = read("lib/activation-guidance.ts");
if (!guidance.includes("ARCHIVE_ONBOARDING_SCREENS")) {
  fail("activation-guidance must map ARCHIVE_ONBOARDING_SCREENS");
}
if (!guidance.includes("ARCHIVE_ONBOARDING_SCREENS")) {
  fail("activation-guidance must derive steps from ARCHIVE_ONBOARDING_SCREENS");
}

const mobile = read("apps/voicememory_mobile/lib/screens/onboarding_screen.dart");
for (const headline of HEADLINES) {
  if (!mobile.includes(headline)) fail(`mobile onboarding missing: ${headline}`);
}
if (!mobile.includes("PageView")) fail("mobile onboarding must use paged flow");
if (mobile.includes("transcribe") || mobile.includes("export JSON")) {
  fail("mobile onboarding must not explain features");
}

const banner = read("components/OnboardingBanner.tsx");
if (banner.includes("/demo") || banner.includes("transcribe")) {
  fail("OnboardingBanner must not explain features");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:archive-onboarding"]) {
  fail("package.json missing validate:archive-onboarding");
}

if (failures.length) {
  console.error("validate-archive-onboarding failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-onboarding ok");
