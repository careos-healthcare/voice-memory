#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
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

const SCAN_DIRS = ["apps/web/app/api", "packages/shared/lib/server", "packages/shared/lib/billing", "packages/shared/lib/persistence"];

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

const structured = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/structured-log.ts"), "utf8");
const sanitizer = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/log-sanitizer.ts"), "utf8");
if (!structured.includes("sanitizeLogRecord")) failures.push("structured-log missing sanitizeLogRecord");
if (!sanitizer.includes("raw_text")) failures.push("log-sanitizer missing raw_text redaction");
if (!sanitizer.includes("citedEntryIds")) failures.push("log-sanitizer missing citedEntryIds redaction");

const mobileValidator = path.join(ROOT, "apps/mobile/tool/validate_mobile_privacy_logs.dart");
if (fs.existsSync(mobileValidator)) {
  try {
    execSync("dart run tool/validate_mobile_privacy_logs.dart", {
      cwd: path.join(ROOT, "apps/mobile"),
      stdio: "pipe",
    });
  } catch (e) {
    failures.push(`mobile privacy log validator failed:\n${e.stdout?.toString() ?? e.message}`);
  }
} else {
  failures.push("apps/mobile/tool/validate_mobile_privacy_logs.dart missing");
}

if (failures.length) {
  console.error("validate-privacy-logs failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-privacy-logs ok");
