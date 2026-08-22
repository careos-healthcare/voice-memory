import "server-only";

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

/** JSON/interface field names that must never appear on public API responses. */
export const BANNED_PUBLIC_RESPONSE_FIELD_PATTERN =
  /\b(biomarkers|lexicalDiversity|cohesionDrift|emotionalVolatility|clinicalTrajectory|cognitiveBaseline|allostaticOverload|overloadState|diagnosticScore|healthMonitoring)\b/;

/** Diagnostic / health-monitoring framing banned from exported response interfaces. */
export const BANNED_PUBLIC_RESPONSE_FRAMING_PATTERN =
  /\b(CognitiveBiomarkers|ClinicalTrajectory|CognitiveAnomaly|MovingBaseline|allostatic\s+overload|health[- ]monitor)/i;

// Anchored to this module rather than process.cwd(). The validator is invoked
// from the repo root, so cwd-relative roots resolved to `<repo>/app/api` and
// `<repo>/../../packages/shared/types` after the monorepo move — three paths
// that do not exist, which made this audit read zero files and pass vacuously.
const MODULE_DIR = fileURLToPath(new URL(".", import.meta.url));
const API_ROOT = join(MODULE_DIR, "../../..");
const REPO_ROOT = join(API_ROOT, "../..");

const PUBLIC_ROUTE_ROOT = join(API_ROOT, "app/api");
const PUBLIC_TYPES_ROOTS = [
  join(API_ROOT, "types"),
  join(REPO_ROOT, "packages/shared/types"),
];

function collectTypeScriptFiles(root: string, acc: string[] = []): string[] {
  let entries: string[] = [];
  try {
    entries = readdirSync(root);
  } catch {
    return acc;
  }

  for (const entry of entries) {
    const fullPath = join(root, entry);
    const stats = statSync(fullPath);
    if (stats.isDirectory()) {
      collectTypeScriptFiles(fullPath, acc);
      continue;
    }
    if (entry.endsWith(".ts") || entry.endsWith(".tsx")) {
      acc.push(fullPath);
    }
  }
  return acc;
}

function auditFile(relativePath: string, source: string): string[] {
  const failures: string[] = [];
  const lines = source.split("\n");

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const lineNumber = index + 1;

    if (line.includes("src/internal/clinical")) continue;

    if (BANNED_PUBLIC_RESPONSE_FIELD_PATTERN.test(line)) {
      failures.push(
        `${relativePath}:${lineNumber} exposes banned clinical response field`,
      );
    }
    if (
      /export\s+(interface|type)\s+/u.test(line) &&
      BANNED_PUBLIC_RESPONSE_FRAMING_PATTERN.test(line)
    ) {
      failures.push(
        `${relativePath}:${lineNumber} exports clinical/diagnostic response type`,
      );
    }
  }

  return failures;
}

/**
 * Static audit — fails when public routes or shared response types leak
 * clinical quarantine terminology.
 */
export function auditPublicApiClinicalSurface(): { failures: string[] } {
  const failures: string[] = [];
  const roots = [PUBLIC_ROUTE_ROOT, ...PUBLIC_TYPES_ROOTS];

  // An audit root that has moved or been deleted must fail loudly. Silently
  // scanning nothing turns this gate into a green light for anything.
  for (const root of roots) {
    if (!existsSync(root)) {
      failures.push(
        `clinical audit root ${root} does not exist — the audit cannot be enforced`,
      );
    }
  }

  const files = roots.flatMap((root) => collectTypeScriptFiles(root));

  if (failures.length === 0 && files.length === 0) {
    failures.push(
      "clinical audit found no TypeScript files under any audit root — refusing to pass vacuously",
    );
  }

  for (const filePath of files) {
    if (filePath.includes("src/internal/clinical")) continue;
    const source = readFileSync(filePath, "utf8");
    failures.push(...auditFile(relative(process.cwd(), filePath), source));
  }

  return { failures };
}
