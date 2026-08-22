#!/usr/bin/env node
/**
 * Writes docs/MOBILE_WEB_PARITY_AUDIT.md from lib/mobile/mobile-web-parity-audit.ts
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const { buildMobileWebParityAudit, formatMobileWebParityAuditMarkdown, MOBILE_WEB_PARITY_AUDIT_DOC } =
  await import(path.join(ROOT, "packages/shared/lib/mobile/mobile-web-parity-audit.ts"));

const audit = buildMobileWebParityAudit();
const md = formatMobileWebParityAuditMarkdown(audit);
const outPath = path.join(ROOT, MOBILE_WEB_PARITY_AUDIT_DOC);
fs.writeFileSync(outPath, md, "utf8");
console.log(`Wrote ${outPath}`);
console.log(`Features: ${audit.features.length}`);
