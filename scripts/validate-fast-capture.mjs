#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const fast = fs.readFileSync(path.join(ROOT, "packages/shared/lib/capture/fast-capture.ts"), "utf8");
for (const fn of ["isFastCaptureReady", "markFastCaptureReady", "shouldDeferNonEssentialHydration", "markAppOpenForCapture"]) {
  if (!fast.includes(fn)) failures.push(`fast-capture missing ${fn}`);
}

const quick = fs.readFileSync(path.join(ROOT, "apps/web/components/capture/QuickRecordPage.tsx"), "utf8");
if (!quick.includes("parseQuickEntryPreview") || !quick.includes("markAppOpenForCapture")) {
  failures.push("QuickRecordPage must preview context and mark app open");
}
if (quick.includes("buildQuietHomepagePresentation")) {
  failures.push("QuickRecordPage must not hydrate homepage presentation");
}

const recordPage = fs.readFileSync(path.join(ROOT, "apps/web/app/record/page.tsx"), "utf8");
if (!recordPage.includes("MicCaptureFallback")) {
  failures.push("/record Suspense fallback must be MicCaptureFallback (no shimmer)");
}

const sw = fs.readFileSync(path.join(ROOT, "apps/web/public/sw.js"), "utf8");
if (!sw.includes("/record") || !sw.includes("warm-capture")) {
  failures.push("service worker must cache and warm /record");
}

const manifest = fs.readFileSync(path.join(ROOT, "apps/web/app/manifest.ts"), "utf8");
if (!manifest.includes("Continue speaking")) {
  failures.push("manifest must include Continue speaking shortcut");
}

if (failures.length > 0) {
  console.error("validate-fast-capture failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-fast-capture ok");
