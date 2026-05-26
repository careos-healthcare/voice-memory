#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/behavior/helpers.ts",
  "lib/behavior/observation.ts",
  "lib/behavior/funnels.ts",
  "lib/behavior/return-analysis.ts",
  "lib/behavior/surface-effectiveness.ts",
  "lib/behavior/copy-effectiveness.ts",
  "lib/behavior/mobile-behavior.ts",
  "lib/behavior/product-pressure.ts",
  "lib/behavior/insight-summary.ts",
  "lib/behavior/behavior-truth-report.ts",
  "types/behavior-truth.ts",
  "app/debug/behavior-truth/page.tsx",
  "components/debug/BehaviorTruthPanel.tsx",
];

const BANNED = [
  /\bgrowth hack/i,
  /\bfunnel optimization\b/i,
  /\bDAU\b/,
  /\bMAU\b/,
  /\bconversion rate\b/i,
  /\bKPI\b/,
  /\bOKR\b/,
  /\bai-powered\b/i,
  /\bmachine learning\b/i,
];

const failures = [];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

const report = fs.readFileSync(
  path.join(ROOT, "lib/behavior/behavior-truth-report.ts"),
  "utf8",
);
if (!report.includes("buildBehaviorTruthReport")) {
  failures.push("behavior-truth-report must export buildBehaviorTruthReport");
}

const insight = fs.readFileSync(path.join(ROOT, "lib/behavior/insight-summary.ts"), "utf8");
if (!insight.includes("buildBehaviorInsightSummary")) {
  failures.push("insight-summary must export buildBehaviorInsightSummary");
}

const page = fs.readFileSync(path.join(ROOT, "app/debug/behavior-truth/page.tsx"), "utf8");
for (const section of [
  "BehaviorTruthPanel",
  "buildBehaviorTruthReport",
  "Behavioral truth",
]) {
  if (!page.includes(section)) {
    failures.push(`behavior-truth page missing ${section}`);
  }
}

const scanDirs = ["lib/behavior", "components/debug/BehaviorTruthPanel.tsx", "app/debug/behavior-truth"];
for (const rel of scanDirs) {
  const full = path.join(ROOT, rel);
  if (!fs.existsSync(full)) continue;
  const files =
    rel.endsWith(".tsx") || rel.endsWith(".ts")
      ? [full]
      : fs.readdirSync(full).map((f) => path.join(full, f));
  for (const file of files) {
    if (!file.endsWith(".ts") && !file.endsWith(".tsx")) continue;
    const text = fs.readFileSync(file, "utf8");
    for (const re of BANNED) {
      if (re.test(text)) {
        failures.push(`${path.relative(ROOT, file)} contains banned phrase: ${re}`);
      }
    }
  }
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:behavior-truth")) {
  failures.push("package.json must wire validate:behavior-truth");
}

if (failures.length > 0) {
  console.error("Behavior truth validation failed:\n");
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}

console.log("Behavior truth validation passed.");
