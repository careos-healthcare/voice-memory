#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const mobile = fs.readFileSync(path.join(ROOT, "packages/shared/lib/mobile/mobile-first-run.ts"), "utf8");
if (!mobile.includes("MOBILE_FIRST_RUN_TAGLINE") || !mobile.includes("isMobileFirstRunHome")) {
  failures.push("mobile-first-run module incomplete");
}

const compressed = fs.readFileSync(
  path.join(ROOT, "apps/web/components/homepage/MobileCompressedHome.tsx"),
  "utf8",
);
if (!compressed.includes("How it works")) {
  failures.push("MobileCompressedHome must tuck copy behind How it works");
}

const home = fs.readFileSync(path.join(ROOT, "apps/web/app/page.tsx"), "utf8");
if (!home.includes("MobileCompressedHome") || !home.includes("mobileFirstRun")) {
  failures.push("homepage must use mobile first-run compression");
}
if (!home.includes("compact={mobileFirstRun || mobileReturning}")) {
  failures.push("homepage must use compact header on mobile first run and returning");
}

const onboarding = fs.readFileSync(path.join(ROOT, "apps/web/app/page.tsx"), "utf8");
if (
  !onboarding.match(/!micCentric && !mobileFirstRun && !mobileReturning[\s\S]*ActivationOnboarding/)
) {
  failures.push("ActivationOnboarding must hide on compressed mobile homepage");
}

if (failures.length > 0) {
  console.error("validate-mobile-first-run failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-mobile-first-run ok");
