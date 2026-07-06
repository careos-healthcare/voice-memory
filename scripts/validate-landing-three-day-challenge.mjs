#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const paths = {
  landingCopy: path.join(ROOT, "lib/product/landing-three-day-challenge-copy.ts"),
  page: path.join(ROOT, "app/page.tsx"),
  component: path.join(ROOT, "components/landing/ThreeDayProofChallengeLanding.tsx"),
  clarity: path.join(ROOT, "lib/product/product-clarity-copy.ts"),
  recognition: path.join(ROOT, "lib/product/recognition-copy.ts"),
};

for (const [name, rel] of Object.entries(paths)) {
  if (!fs.existsSync(rel)) {
    console.error(`Landing 3-day challenge validation failed — missing ${name}: ${rel}`);
    process.exit(1);
  }
}

const blobs = Object.values(paths).map((rel) => fs.readFileSync(rel, "utf8")).join("\n");
const consumerBlobs = [
  paths.page,
  paths.component,
  paths.clarity,
  paths.recognition,
]
  .map((rel) => fs.readFileSync(rel, "utf8"))
  .join("\n");

const required = [
  "See what keeps coming back.",
  "Record one private moment a day for 3 days",
  "Start the 3-day proof challenge",
  "How it works",
  "ChatGPT helps you think today. ArchiveMe shows what keeps repeating across your life.",
  "Pro keeps the longer story",
  "Longer archive history",
  "Private monthly reports",
  "Evidence over time",
  "Pattern correction history",
  "planned Pro area",
  "Not therapy or medical advice",
  "ThreeDayProofChallengeLanding",
  "landing-three-day-challenge",
];

for (const token of required) {
  if (!blobs.includes(token)) {
    console.error(`Landing 3-day challenge validation failed — missing ${token}`);
    process.exit(1);
  }
}

const bannedLiveClaims = [
  "your archive is backed up",
  "sync is active",
  "cloud backup included",
  "recovered automatically",
  "guaranteed transformation",
  "universal mental health benefit",
  "more ai",
  "smarter chat",
];

for (const phrase of bannedLiveClaims) {
  if (consumerBlobs.toLowerCase().includes(phrase)) {
    console.error(`Landing 3-day challenge validation failed — banned live claim: ${phrase}`);
    process.exit(1);
  }
}

const proBlob = blobs.toLowerCase();
if (!proBlob.includes("longer archive") && !proBlob.includes("private monthly")) {
  console.error("Landing 3-day challenge validation failed — Pro section missing archive/report value");
  process.exit(1);
}

console.log("Landing 3-day challenge validation passed.");
