#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const paths = {
  landingCopy: path.join(ROOT, "packages/shared/lib/product/landing-three-day-challenge-copy.ts"),
  page: path.join(ROOT, "apps/web/app/page.tsx"),
  component: path.join(ROOT, "apps/web/components/landing/ThreeDayProofChallengeLanding.tsx"),
  clarity: path.join(ROOT, "packages/shared/lib/product/product-clarity-copy.ts"),
  recognition: path.join(ROOT, "packages/shared/lib/product/recognition-copy.ts"),
  howItWorks: path.join(ROOT, "packages/shared/lib/tester-onboarding-copy.ts"),
  pricingShell: path.join(ROOT, "apps/web/components/pricing/PricingStaticShell.tsx"),
  pricingCopy: path.join(ROOT, "packages/shared/lib/billing/value-moment-paywall-copy.ts"),
};

for (const [name, rel] of Object.entries(paths)) {
  if (!fs.existsSync(rel)) {
    console.error(`Landing page alignment validation failed — missing ${name}: ${rel}`);
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
  "See what keeps returning",
  "No daily journal required.",
  "Save small moments when something stands out",
  "Save one small moment",
  "Come back when something stands out",
  "See what returned",
  "Correct what is not relevant",
  "Keep the full timeline with Pro",
  "ChatGPT can answer a conversation. ArchiveMe shows the timeline behind the pattern.",
  "Pro keeps the full timeline as it grows.",
  "Free shows the first proof. Pro keeps the full timeline as it grows.",
  "Full pattern timeline",
  "Correction history",
  "Monthly private report",
  "Not therapy or medical advice",
  "ThreeDayProofChallengeLanding",
  "landing-three-day-challenge",
];

for (const token of required) {
  if (!blobs.includes(token)) {
    console.error(`Landing page alignment validation failed — missing ${token}`);
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
  "ai therapist",
  "mental health treatment",
];

for (const phrase of bannedLiveClaims) {
  if (consumerBlobs.toLowerCase().includes(phrase)) {
    console.error(`Landing page alignment validation failed — banned live claim: ${phrase}`);
    process.exit(1);
  }
}

const bannedTherapyPromotion = /\b(therapy|diagnosis|medical treatment)\b/i;
const trustExceptions = /not therapy|not a diagnos|not medical advice/i;
if (bannedTherapyPromotion.test(consumerBlobs) && !trustExceptions.test(consumerBlobs)) {
  console.error(
    "Landing page alignment validation failed — therapy/medical promotion without disclaimer",
  );
  process.exit(1);
}

const testimonialPatterns = [
  /"\s*-\s*[A-Z][a-z]+/,
  /testimonial/i,
  /★★★★★/,
  /verified user/i,
];
for (const pattern of testimonialPatterns) {
  if (pattern.test(consumerBlobs)) {
    console.error(
      `Landing page alignment validation failed — possible fake testimonial: ${pattern}`,
    );
    process.exit(1);
  }
}

console.log("Landing page alignment validation passed.");
