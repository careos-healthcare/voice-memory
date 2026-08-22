#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const CHILD = [
  "validate:archive-asset-value",
  "validate:hard-to-reproduce-proof",
  "validate:archive-moat-copy",
];

const REQUIRED_INTERNAL = [
  "packages/shared/lib/internal/retention-moat-report.ts",
  "apps/web/components/internal/RetentionMoatPanel.tsx",
];

for (const rel of REQUIRED_INTERNAL) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`validate-competitor-retention-fixes: missing ${rel}`);
    process.exit(1);
  }
}

const retentionPage = fs.readFileSync(
  path.join(ROOT, "apps/web/app/internal/retention-discovery/page.tsx"),
  "utf8",
);
if (!retentionPage.includes("RetentionMoatPanel")) {
  console.error("retention-discovery must include RetentionMoatPanel");
  process.exit(1);
}

for (const script of CHILD) {
  const r = spawnSync("npm", ["run", script], { cwd: ROOT, stdio: "inherit", shell: true });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

const build = spawnSync("npm", ["run", "build"], { cwd: ROOT, stdio: "inherit", shell: true });
if (build.status !== 0) process.exit(build.status ?? 1);

console.log("validate-competitor-retention-fixes ok");
