#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const required = [
  "packages/shared/lib/mobile/mobile-first-run.ts",
  "packages/shared/lib/mobile/homepage-mobile-compression.ts",
  "apps/web/components/homepage/MobileReturningHome.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const mobile = fs.readFileSync(path.join(ROOT, "packages/shared/lib/mobile/mobile-first-run.ts"), "utf8");
if (!mobile.includes("isMobileReturningHome")) {
  failures.push("mobile-first-run must export isMobileReturningHome");
}

const returning = fs.readFileSync(
  path.join(ROOT, "apps/web/components/homepage/MobileReturningHome.tsx"),
  "utf8",
);
if (!returning.includes("FirstReturnMoment") || !returning.includes('presentation="quiet"')) {
  failures.push("MobileReturningHome must lead with quiet FirstReturnMoment when available");
}
if (!returning.includes("ReturnThreadCard")) {
  failures.push("MobileReturningHome must keep thread fallback");
}

const habit = fs.readFileSync(path.join(ROOT, "apps/web/components/HabitLoopCard.tsx"), "utf8");
if ((habit.match(/this week/g) ?? []).length > 4) {
  failures.push("HabitLoopCard compact should not repeat weekly count");
}

const home = fs.readFileSync(path.join(ROOT, "apps/web/app/page.tsx"), "utf8");
if (!home.includes("MobileReturningHome") || !home.includes("mobileReturning")) {
  failures.push("homepage must use mobile returning compression");
}
if (!home.includes("captureFirstHome")) {
  failures.push("homepage must define captureFirstHome");
}
if (!home.match(/!captureFirstHome/)) {
  failures.push("homepage explanatory stack must hide when capture-first");
}
if (!home.includes("captureFirstHome")) {
  failures.push("homepage must use captureFirstHome for mobile returning compression");
}

const compression = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/mobile/homepage-mobile-compression.ts"),
  "utf8",
);
if (!compression.includes("pickMobileHomeSecondary")) {
  failures.push("homepage-mobile-compression incomplete");
}

if (failures.length > 0) {
  console.error("validate-homepage-mobile-compression failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-homepage-mobile-compression ok");
