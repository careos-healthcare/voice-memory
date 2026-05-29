#!/usr/bin/env node
/**
 * Export voice-memory project into 10 TextEdit-readable .txt files.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, "..");
const OUTPUT_DIR = "/Users/chiragpatel/Desktop/spp20/project_textedit_export";
const SPP20_DIR = "/Users/chiragpatel/Desktop/spp20";

const OUTPUT_FILES = [
  "01_project_overview_and_configs.txt",
  "02_app_routes_pages_layouts.txt",
  "03_ui_components_design_system.txt",
  "04_backend_api_server_auth_billing.txt",
  "05_ai_memory_emotional_resurfacing.txt",
  "06_data_persistence_journal_sync_migrations.txt",
  "07_dart_flutter_mobile_code.txt",
  "08_tests_playwright_validators_scripts.txt",
  "09_docs_reports_audits.txt",
  "10_full_file_inventory_and_missing_items.txt",
];

const EXCLUDED_DIRS = new Set([
  "node_modules",
  ".next",
  "dist",
  "build",
  "coverage",
  ".git",
  "Pods",
  "DerivedData",
  ".dart_tool",
  "ios",
  "android",
  "test-results",
  "playwright-report",
  ".cursor",
  ".turbo",
  "out",
]);

const BINARY_EXT = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".ico",
  ".svg",
  ".woff",
  ".woff2",
  ".ttf",
  ".eot",
  ".mp3",
  ".wav",
  ".ogg",
  ".zip",
  ".gz",
  ".pdf",
  ".bin",
  ".exe",
  ".dll",
  ".so",
  ".dylib",
  ".lockb",
]);

const TEXT_EXT = new Set([
  ".ts",
  ".tsx",
  ".js",
  ".jsx",
  ".mjs",
  ".cjs",
  ".css",
  ".scss",
  ".html",
  ".json",
  ".md",
  ".mdx",
  ".yaml",
  ".yml",
  ".sql",
  ".sh",
  ".env",
  ".example",
  ".txt",
  ".xml",
  ".toml",
  ".config",
  ".webmanifest",
  ".gitignore",
  ".gitattributes",
  ".npmrc",
  ".nvmrc",
  ".editorconfig",
  ".prettierrc",
  ".eslintrc",
]);

const SECRET_PATTERNS = [
  { re: /sk_live_[A-Za-z0-9]+/g, rep: "sk_live_[REDACTED]" },
  { re: /sk_test_[A-Za-z0-9]+/g, rep: "sk_test_[REDACTED]" },
  { re: /whsec_[A-Za-z0-9]+/g, rep: "whsec_[REDACTED]" },
  { re: /(OPENAI_API_KEY=)([^\n\r]+)/gi, rep: "$1[REDACTED]" },
  { re: /(DATABASE_URL=)([^\n\r]+)/gi, rep: "$1[REDACTED]" },
  { re: /(AUTH_SECRET=)([^\n\r]+)/gi, rep: "$1[REDACTED]" },
  { re: /(STRIPE_SECRET_KEY=)([^\n\r]+)/gi, rep: "$1[REDACTED]" },
  { re: /(STRIPE_WEBHOOK_SECRET=)([^\n\r]+)/gi, rep: "$1[REDACTED]" },
  { re: /(RESEND_API_KEY=)([^\n\r]+)/gi, rep: "$1[REDACTED]" },
  { re: /(DEBUG_ACCESS_TOKEN=)([^\n\r]+)/gi, rep: "$1[REDACTED]" },
  { re: /(STRIPE_PRO_PRICE_ID=)([^\n\r]+)/gi, rep: "$1[REDACTED]" },
  { re: /(EMAIL_FROM=)([^\n\r]+)/gi, rep: "$1[REDACTED]" },
  { re: /postgres:\/\/[^\s\n\r'"]+/gi, rep: "postgres://[REDACTED]" },
  { re: /mongodb(\+srv)?:\/\/[^\s\n\r'"]+/gi, rep: "mongodb://[REDACTED]" },
];

const MAX_FILE_BYTES = 512 * 1024;
const buckets = Object.fromEntries(OUTPUT_FILES.map((f) => [f, []]));

const stats = {
  exported: [],
  skipped: [],
  skippedBinary: [],
  redacted: [],
  warnings: [],
  tooLarge: [],
  unresolved: [],
};

function redact(content, filePath) {
  let out = content;
  let changed = false;
  for (const { re, rep } of SECRET_PATTERNS) {
    const next = out.replace(re, rep);
    if (next !== out) changed = true;
    out = next;
  }
  if (changed) stats.redacted.push(filePath);
  return out;
}

function isExcludedDir(name) {
  return EXCLUDED_DIRS.has(name) || name.startsWith(".");
}

function fileType(rel, ext) {
  if (ext === ".tsx") return "tsx";
  if (ext === ".ts") return "typescript";
  if (ext === ".jsx") return "jsx";
  if (ext === ".js" || ext === ".mjs" || ext === ".cjs") return "javascript";
  if (ext === ".css") return "css";
  if (ext === ".json") return "json";
  if (ext === ".md") return "markdown";
  if (ext === ".sql") return "sql";
  if (ext === ".sh") return "shell";
  if (rel.includes(".env")) return "env";
  return ext.replace(/^\./, "") || "text";
}

function classifyProjectFile(rel) {
  const norm = rel.replace(/\\/g, "/");
  const lower = norm.toLowerCase();

  if (
    lower === "package.json" ||
    lower === "package-lock.json" ||
    lower === "tsconfig.json" ||
    lower.startsWith("tsconfig.") ||
    lower === "next.config.ts" ||
    lower === "next.config.js" ||
    lower === "middleware.ts" ||
    lower === "instrumentation.ts" ||
    lower === "playwright.config.ts" ||
    lower.startsWith("playwright.") ||
    lower === "postcss.config.mjs" ||
    lower === "eslint.config.mjs" ||
    lower === "components.json" ||
    lower === "vercel.json" ||
    lower === "turbo.json" ||
    lower === "readme.md" ||
    lower === "agents.md" ||
    lower === "claude.md" ||
    lower === ".gitignore" ||
    lower === ".env.example" ||
    lower.endsWith(".example") ||
    lower.startsWith(".env")
  ) {
    return "01_project_overview_and_configs.txt";
  }

  if (lower.startsWith("app/api/")) return "04_backend_api_server_auth_billing.txt";
  if (lower.startsWith("app/")) return "02_app_routes_pages_layouts.txt";

  if (lower.startsWith("components/")) return "03_ui_components_design_system.txt";

  if (
    lower.startsWith("lib/server/") ||
    lower.startsWith("lib/billing/") ||
    lower.startsWith("lib/entitlement/") ||
    lower.startsWith("lib/reliability/") ||
    lower.startsWith("lib/notifications/") ||
    lower === "middleware.ts" ||
    lower === "instrumentation.ts"
  ) {
    return "04_backend_api_server_auth_billing.txt";
  }

  if (
    lower.startsWith("lib/openai") ||
    lower.includes("/openai") ||
    lower.startsWith("lib/memory/") ||
    lower.startsWith("lib/resurfacing/") ||
    lower.startsWith("lib/emotional") ||
    lower.startsWith("lib/patterns/") ||
    lower.startsWith("lib/refinement/") ||
    lower.startsWith("lib/continuity/") ||
    lower.startsWith("lib/clarity/") ||
    lower.startsWith("lib/conversation/") ||
    lower.startsWith("lib/reflection/") ||
    lower.startsWith("lib/revisit/") ||
    lower.startsWith("lib/territories/") ||
    lower.startsWith("lib/atmosphere/") ||
    lower.startsWith("lib/open-loops/") ||
    lower.startsWith("lib/emotional-quality/")
  ) {
    return "05_ai_memory_emotional_resurfacing.txt";
  }

  if (
    lower.startsWith("lib/storage") ||
    lower.startsWith("lib/sync/") ||
    lower.startsWith("lib/server/journal") ||
    lower.startsWith("lib/persistence/") ||
    lower.startsWith("lib/archive/") ||
    lower.startsWith("lib/account/") ||
    lower.startsWith("docs/sql/") ||
    lower.endsWith(".sql")
  ) {
    return "06_data_persistence_journal_sync_migrations.txt";
  }

  if (lower.endsWith(".dart") || lower.startsWith("lib/") && lower.includes("flutter")) {
    return "07_dart_flutter_mobile_code.txt";
  }

  if (
    lower.startsWith("e2e/") ||
    lower.startsWith("scripts/") ||
    lower.includes(".spec.") ||
    lower.includes(".test.") ||
    lower.startsWith("__tests__/")
  ) {
    return "08_tests_playwright_validators_scripts.txt";
  }

  if (lower.startsWith("docs/")) return "09_docs_reports_audits.txt";

  if (lower.startsWith("lib/")) return "05_ai_memory_emotional_resurfacing.txt";
  if (lower.startsWith("types/")) return "05_ai_memory_emotional_resurfacing.txt";
  if (lower.startsWith("public/")) return "01_project_overview_and_configs.txt";
  if (lower.startsWith("app/")) return "02_app_routes_pages_layouts.txt";

  return "10_full_file_inventory_and_missing_items.txt";
}

function classifySpp20Report(absPath, relFromSpp20) {
  return "09_docs_reports_audits.txt";
}

function walk(dir, baseRel = "") {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const ent of entries) {
    if (ent.isDirectory()) {
      if (isExcludedDir(ent.name)) continue;
      walk(path.join(dir, ent.name), baseRel ? `${baseRel}/${ent.name}` : ent.name);
      continue;
    }
    if (!ent.isFile()) continue;
    const rel = baseRel ? `${baseRel}/${ent.name}` : ent.name;
    const abs = path.join(dir, ent.name);
    const ext = path.extname(ent.name).toLowerCase();
    const base = path.basename(ent.name);

    if (BINARY_EXT.has(ext)) {
      stats.skippedBinary.push({ path: abs, relative: rel, reason: "binary extension" });
      continue;
    }

    const allowed =
      TEXT_EXT.has(ext) ||
      base === "AGENTS.md" ||
      base === "CLAUDE.md" ||
      base === "LICENSE" ||
      rel.includes(".env");

    if (!allowed) {
      stats.skipped.push({ path: abs, relative: rel, reason: `unsupported type ${ext || "(none)"}` });
      continue;
    }

    let st;
    try {
      st = fs.statSync(abs);
    } catch {
      stats.skipped.push({ path: abs, relative: rel, reason: "stat failed" });
      continue;
    }

    if (st.size > MAX_FILE_BYTES) {
      stats.tooLarge.push({ path: abs, relative: rel, size: st.size });
      buckets["10_full_file_inventory_and_missing_items.txt"].push({
        abs,
        rel,
        ext,
        st,
        content: `[FILE TOO LARGE: ${st.size} bytes — omitted from dump; see repo directly]\n`,
        bucket: "10_full_file_inventory_and_missing_items.txt",
        source: "voice-memory",
      });
      continue;
    }

    let raw;
    try {
      raw = fs.readFileSync(abs, "utf8");
    } catch {
      stats.skipped.push({ path: abs, relative: rel, reason: "unreadable utf8" });
      continue;
    }

    const content = redact(raw, abs);
    const bucket = classifyProjectFile(rel);
    buckets[bucket].push({
      abs,
      rel,
      ext,
      st,
      content,
      bucket,
      source: "voice-memory",
    });
    stats.exported.push({ path: abs, relative: rel, bucket, size: st.size });
  }
}

function addSpp20Reports() {
  if (!fs.existsSync(SPP20_DIR)) return;
  const entries = fs.readdirSync(SPP20_DIR, { withFileTypes: true });
  for (const ent of entries) {
    if (!ent.isFile() || !ent.name.endsWith(".md")) continue;
    const abs = path.join(SPP20_DIR, ent.name);
    const rel = `spp20-reports/${ent.name}`;
    const st = fs.statSync(abs);
    const content = redact(fs.readFileSync(abs, "utf8"), abs);
    buckets["09_docs_reports_audits.txt"].push({
      abs,
      rel,
      ext: ".md",
      st,
      content,
      bucket: "09_docs_reports_audits.txt",
      source: "spp20",
    });
    stats.exported.push({ path: abs, relative: rel, bucket: "09_docs_reports_audits.txt", size: st.size });
  }
}

function formatEntry(entry) {
  const mod = entry.st.mtime.toISOString();
  const type = fileType(entry.rel, entry.ext);
  return [
    "===== FILE START =====",
    `PATH: ${entry.abs}`,
    `RELATIVE: ${entry.rel}`,
    `SOURCE: ${entry.source}`,
    `TYPE: ${type}`,
    `SIZE: ${entry.st.size}`,
    `MODIFIED: ${mod}`,
    "===== CONTENT =====",
    entry.content,
    "===== FILE END =====",
    "",
  ].join("\n");
}

function writeBucket(filename, title, entries) {
  entries.sort((a, b) => a.rel.localeCompare(b.rel));
  const toc = entries.map((e, i) => `${i + 1}. ${e.rel} (${e.st.size} bytes)`).join("\n");
  const header = [
    title,
    "=".repeat(title.length),
    `Generated: ${new Date().toISOString()}`,
    `Project root: ${PROJECT_ROOT}`,
    `Files in this volume: ${entries.length}`,
    "",
    "TABLE OF CONTENTS",
    "-".repeat(40),
    toc || "(no files in this volume)",
    "",
    "=".repeat(40),
    "",
  ].join("\n");
  const body = entries.map(formatEntry).join("\n");
  fs.writeFileSync(path.join(OUTPUT_DIR, filename), header + body, "utf8");
}

function scanSecretsInOutput() {
  const scanPatterns = [
    /sk_live_[A-Za-z0-9]{8,}/,
    /sk_test_[A-Za-z0-9]{8,}/,
    /whsec_[A-Za-z0-9]{8,}/,
    /OPENAI_API_KEY=[^\[\n\r]+/i,
    /DATABASE_URL=[^\[\n\r]+/i,
    /AUTH_SECRET=[^\[\n\r]+/i,
    /STRIPE_SECRET_KEY=[^\[\n\r]+/i,
    /RESEND_API_KEY=[^\[\n\r]+/i,
  ];
  const hits = [];
  for (const fname of [...OUTPUT_FILES, "README_EXPORT.txt"]) {
    const p = path.join(OUTPUT_DIR, fname);
    if (!fs.existsSync(p)) continue;
    const text = fs.readFileSync(p, "utf8");
    for (const re of scanPatterns) {
      if (re.test(text)) {
        const bad = text.match(re)?.[0] ?? "match";
        if (!bad.includes("[REDACTED]")) hits.push({ file: fname, match: bad.slice(0, 40) });
      }
    }
  }
  return hits;
}

function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  walk(PROJECT_ROOT);
  addSpp20Reports();

  // File 07: explicit note if no Dart
  const dartFiles = stats.exported.filter((e) => e.relative.endsWith(".dart"));
  if (dartFiles.length === 0) {
    buckets["07_dart_flutter_mobile_code.txt"].push({
      abs: "(none)",
      rel: "(inventory)",
      ext: ".txt",
      st: { size: 0, mtime: new Date() },
      content:
        "No .dart files were found under the voice-memory project root.\n" +
        "Excluded: ios/, android/, .dart_tool/, Pods/, DerivedData/ per export rules.\n" +
        "Mobile-related TypeScript lives in lib/mobile/, components/, and app/ (see volumes 02–03).\n",
      bucket: "07_dart_flutter_mobile_code.txt",
      source: "export-script",
    });
  }

  // File 10: inventory + skipped
  const invLines = [
    "FULL FILE INVENTORY AND SKIPPED ITEMS",
    "===================================",
    "",
    `Total exported: ${stats.exported.length}`,
    `Total skipped: ${stats.skipped.length}`,
    `Binary skipped: ${stats.skippedBinary.length}`,
    `Too large (stub only): ${stats.tooLarge.length}`,
    `Redacted files: ${stats.redacted.length}`,
    "",
    "EXCLUDED DIRECTORIES",
    [...EXCLUDED_DIRS].join(", "),
    "",
    "SKIPPED FILES (sample, first 200)",
    ...stats.skipped.slice(0, 200).map((s) => `- ${s.relative}: ${s.reason}`),
    "",
    "SKIPPED BINARY (count by extension)",
  ];
  const binCounts = {};
  for (const b of stats.skippedBinary) {
    const ext = path.extname(b.relative).toLowerCase() || "(none)";
    binCounts[ext] = (binCounts[ext] || 0) + 1;
  }
  invLines.push(...Object.entries(binCounts).map(([k, v]) => `  ${k}: ${v}`));
  invLines.push("", "ALL EXPORTED FILES BY BUCKET");
  for (const f of OUTPUT_FILES) {
    const n = buckets[f].length;
    invLines.push(`  ${f}: ${n}`);
  }
  invLines.push("", "UNRESOLVED / CATCH-ALL", ...stats.unresolved.map((u) => `- ${u}`));

  buckets["10_full_file_inventory_and_missing_items.txt"].unshift({
    abs: path.join(OUTPUT_DIR, "10_full_file_inventory_and_missing_items.txt"),
    rel: "_inventory_summary",
    ext: ".txt",
    st: { size: invLines.join("\n").length, mtime: new Date() },
    content: invLines.join("\n") + "\n",
    bucket: "10_full_file_inventory_and_missing_items.txt",
    source: "export-script",
  });

  const titles = {
    "01_project_overview_and_configs.txt": "01 — Project overview and configs",
    "02_app_routes_pages_layouts.txt": "02 — App routes, pages, layouts",
    "03_ui_components_design_system.txt": "03 — UI components and design system",
    "04_backend_api_server_auth_billing.txt": "04 — Backend, API, server, auth, billing",
    "05_ai_memory_emotional_resurfacing.txt": "05 — AI, memory, emotional resurfacing",
    "06_data_persistence_journal_sync_migrations.txt": "06 — Data, journal, sync, migrations",
    "07_dart_flutter_mobile_code.txt": "07 — Dart / Flutter mobile code",
    "08_tests_playwright_validators_scripts.txt": "08 — Tests, Playwright, validators, scripts",
    "09_docs_reports_audits.txt": "09 — Docs, reports, audits",
    "10_full_file_inventory_and_missing_items.txt": "10 — Full inventory and skipped items",
  };

  for (const f of OUTPUT_FILES) writeBucket(f, titles[f], buckets[f]);

  let totalBytes = 0;
  for (const f of OUTPUT_FILES) {
    totalBytes += fs.statSync(path.join(OUTPUT_DIR, f)).size;
  }

  const secretHits = scanSecretsInOutput();
  if (secretHits.length) {
    stats.warnings.push(`Secret scan found ${secretHits.length} hits — re-redacting`);
    for (const h of secretHits) {
      let t = fs.readFileSync(path.join(OUTPUT_DIR, h.file), "utf8");
      t = redact(t, h.file);
      fs.writeFileSync(path.join(OUTPUT_DIR, h.file), t, "utf8");
    }
  }
  const secretHitsAfter = scanSecretsInOutput();

  const readme = [
    "Voice Memory — TextEdit Project Export",
    "========================================",
    "",
    `Generated: ${new Date().toISOString()}`,
    `Project root: ${PROJECT_ROOT}`,
    `Output directory: ${OUTPUT_DIR}`,
    "",
    "WHAT WAS EXPORTED",
    "- TypeScript/JavaScript (app, components, lib, types, e2e, scripts)",
    "- CSS, JSON, Markdown, SQL, shell scripts, config files",
    "- Playwright configs and UI/validator tests",
    "- Documentation under docs/",
    "- SPP20 audit/report markdown files (spp20-reports/*.md)",
    "",
    "WHAT WAS EXCLUDED",
    "- node_modules, .next, build, dist, coverage, .git",
    "- test-results, playwright-report, .cursor",
    "- ios/, android/, Pods/, DerivedData/, .dart_tool/",
    "- Binary/media: images, fonts, audio, archives, etc.",
    "",
    "SECRETS REDACTION",
    "- .env and secret-like values replaced with [REDACTED]",
    "- Patterns: Stripe keys, webhook secrets, OPENAI_API_KEY, DATABASE_URL,",
    "  AUTH_SECRET, RESEND_API_KEY, postgres:// URLs, etc.",
    "",
    "HOW TO OPEN IN TEXTEDIT (macOS)",
    "1. Open Finder → Desktop → spp20 → project_textedit_export",
    "2. Double-click any .txt file (opens in TextEdit by default)",
    "3. For large files: TextEdit → Format → Make Plain Text if needed",
    "4. Use Edit → Find → Find… to search across files",
    "",
    "VOLUME FILES (10)",
    ...OUTPUT_FILES.map((f) => `  - ${f}`),
    "",
    `Total source files exported: ${stats.exported.length}`,
    `Total export bytes (all .txt volumes): ${totalBytes}`,
    `Secret scan after export: ${secretHitsAfter.length === 0 ? "PASS (no raw secrets)" : "FAIL — see export_verification_report.txt"}`,
    "",
  ].join("\n");
  fs.writeFileSync(path.join(OUTPUT_DIR, "README_EXPORT.txt"), readme, "utf8");

  const manifest = {
    generatedAt: new Date().toISOString(),
    projectRoot: PROJECT_ROOT,
    outputDir: OUTPUT_DIR,
    filesCreated: [...OUTPUT_FILES, "README_EXPORT.txt", "export_manifest.json", "export_verification_report.txt"],
    totalSourceFilesExported: stats.exported.length,
    totalBytesExported: totalBytes,
    excludedDirectories: [...EXCLUDED_DIRS],
    skippedBinaryFiles: stats.skippedBinary.length,
    redactedFiles: stats.redacted.length,
    warnings: stats.warnings,
    secretScanPass: secretHitsAfter.length === 0,
    buckets: Object.fromEntries(OUTPUT_FILES.map((f) => [f, buckets[f].length])),
  };
  fs.writeFileSync(
    path.join(OUTPUT_DIR, "export_manifest.json"),
    JSON.stringify(manifest, null, 2),
    "utf8",
  );

  const verify = [
    "EXPORT VERIFICATION REPORT",
    "========================",
    `Generated: ${new Date().toISOString()}`,
    "",
    "FILES CREATED",
    ...OUTPUT_FILES.map((f) => {
      const p = path.join(OUTPUT_DIR, f);
      const st = fs.statSync(p);
      return `  ${f} — ${st.size} bytes`;
    }),
    "  README_EXPORT.txt",
    "  export_manifest.json",
    "  export_verification_report.txt",
    "",
    `SOURCE FILES EXPORTED: ${stats.exported.length}`,
    `SOURCE FILES SKIPPED: ${stats.skipped.length}`,
    `BINARY SKIPPED: ${stats.skippedBinary.length}`,
    `FILES REDACTED: ${stats.redacted.length}`,
    `TOO LARGE (stub in vol 10): ${stats.tooLarge.length}`,
    "",
    "SECRET SCAN RESULT",
    secretHitsAfter.length === 0
      ? "  PASS — no raw secret patterns detected in export .txt files"
      : `  FAIL — ${secretHitsAfter.length} pattern(s): ${JSON.stringify(secretHitsAfter)}`,
    "",
    "WARNINGS",
    ...(stats.warnings.length ? stats.warnings.map((w) => `  - ${w}`) : ["  (none)"]),
    "",
    "FILES TOO LARGE OR UNREADABLE",
    ...(stats.tooLarge.length
      ? stats.tooLarge.map((t) => `  - ${t.relative} (${t.size} bytes)`)
      : ["  (none)"]),
    ...(stats.skipped.slice(0, 50).length
      ? ["", "SKIPPED SAMPLE (first 50)", ...stats.skipped.slice(0, 50).map((s) => `  - ${s.relative}`)]
      : []),
    "",
  ].join("\n");
  fs.writeFileSync(path.join(OUTPUT_DIR, "export_verification_report.txt"), verify, "utf8");

  console.log("Export complete.");
  console.log(`Exported: ${stats.exported.length} files, ${totalBytes} bytes in volumes`);
  console.log(`Secret scan: ${secretHitsAfter.length === 0 ? "PASS" : "FAIL"}`);
}

main();
