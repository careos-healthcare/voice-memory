#!/usr/bin/env node
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const warnings = [];

if (fs.existsSync(path.join(ROOT, ".env"))) {
  failures.push(".env file present in repo — must not be committed");
}

const secretPatterns = [
  /sk_live_[a-zA-Z0-9]{10,}/,
  /sk_test_[a-zA-Z0-9]{10,}/,
  /whsec_[a-zA-Z0-9]{10,}/,
  /re_[a-zA-Z0-9]{10,}/,
];

function scanSecrets(dir) {
  if (!fs.existsSync(dir)) return;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (
      ent.name === "node_modules" ||
      ent.name === ".git" ||
      ent.name === ".next" ||
      ent.name === "dist"
    ) {
      continue;
    }
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) scanSecrets(p);
    else if (/\.(ts|tsx|js|mjs|json|md)$/.test(ent.name) && !ent.name.includes("package-lock")) {
      const text = fs.readFileSync(p, "utf8");
      for (const re of secretPatterns) {
        if (re.test(text) && !p.includes("validate-supply-chain")) {
          warnings.push(`possible secret pattern in ${p}`);
        }
      }
    }
  }
}

scanSecrets(ROOT);

try {
  const audit = execSync("npm audit --omit=dev --json 2>/dev/null || true", {
    cwd: ROOT,
    encoding: "utf8",
  });
  const parsed = JSON.parse(audit || "{}");
  const critical = parsed.metadata?.vulnerabilities?.critical ?? 0;
  const high = parsed.metadata?.vulnerabilities?.high ?? 0;
  if (critical > 0) failures.push(`npm audit: ${critical} critical vulnerabilities`);
  if (high > 5) warnings.push(`npm audit: ${high} high vulnerabilities (review)`);
} catch {
  warnings.push("npm audit skipped or unavailable");
}

if (warnings.length) console.warn("validate-supply-chain warnings:\n", warnings.join("\n"));

if (failures.length) {
  console.error("validate-supply-chain failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-supply-chain ok");
