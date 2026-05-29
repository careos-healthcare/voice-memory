#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const BANNED_PATTERNS = [
  {
    re: /console\.(log|info|error|warn)\([^)]*\btranscript\b/i,
    msg: "raw transcript in console",
  },
  { re: /logServerEvent\([^)]*transcript/i, msg: "transcript in structured log fields" },
  { re: /sk_live_[a-zA-Z0-9]+/, msg: "possible live Stripe secret in source" },
  { re: /whsec_[a-zA-Z0-9]{20,}/, msg: "possible webhook secret in source" },
  { re: /Bearer\s+[a-zA-Z0-9._-]{20,}/, msg: "possible bearer token literal" },
];

const SCAN_DIRS = ["app/api", "lib/server", "lib/billing", "lib/persistence"];

function walk(dir, files = []) {
  if (!fs.existsSync(dir)) return files;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, files);
    else if (/\.(ts|tsx|mjs)$/.test(ent.name)) files.push(p);
  }
  return files;
}

for (const sub of SCAN_DIRS) {
  for (const file of walk(path.join(ROOT, sub))) {
    const text = fs.readFileSync(file, "utf8");
    if (/log\s*\(\s*\{[^}]*\bemail\s*:\s*session\.email/.test(text)) {
      failures.push(`${file}: logs raw email (use emailHash)`);
    }
    for (const { re, msg } of BANNED_PATTERNS) {
      if (re.test(text)) failures.push(`${file}: ${msg}`);
    }
  }
}

const structured = fs.readFileSync(path.join(ROOT, "lib/server/structured-log.ts"), "utf8");
if (!structured.includes("banned")) failures.push("structured-log missing sanitization");

if (failures.length) {
  console.error("validate-privacy-logs failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-privacy-logs ok");
