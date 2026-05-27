#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const layout = fs.readFileSync(path.join(ROOT, "app/record/layout.tsx"), "utf8");
const quick = fs.readFileSync(path.join(ROOT, "components/capture/QuickRecordPage.tsx"), "utf8");
const capture = fs.readFileSync(
  path.join(ROOT, "components/capture/RecordFullscreenCapture.tsx"),
  "utf8",
);

if (!capture.includes('data-record-capture="true"')) {
  failures.push("RecordFullscreenCapture must mark record capture surface");
}
if (!capture.includes("bg-zinc-950")) {
  failures.push("RecordFullscreenCapture must use dark background");
}
if (quick.includes("SiteHeader") || quick.includes("SiteFooter")) {
  failures.push("QuickRecordPage must not include site header/footer");
}
if (layout.includes("SiteHeader") || layout.includes("SiteFooter")) {
  failures.push("record layout must not include site header/footer");
}
if (!quick.includes("ZeroStateRecorderShell")) {
  failures.push("QuickRecordPage must use ZeroStateRecorderShell");
}

const gate = fs.readFileSync(path.join(ROOT, "lib/mobile/install-prompt-gate.ts"), "utf8");
if (!gate.includes('"/record"')) {
  failures.push("install prompt gate must block /record");
}

if (failures.length > 0) {
  console.error("validate-mobile-record-fullscreen failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-mobile-record-fullscreen ok");
