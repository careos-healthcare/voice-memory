import "server-only";

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

/** JSON/interface field names that must never appear on public API responses. */
export const BANNED_PUBLIC_RESPONSE_FIELD_PATTERN =
  /\b(biomarkers|lexicalDiversity|cohesionDrift|emotionalVolatility|clinicalTrajectory|cognitiveBaseline|allostaticOverload|overloadState|diagnosticScore|healthMonitoring)\b/;

/** Diagnostic / health-monitoring framing banned from exported response interfaces. */
export const BANNED_PUBLIC_RESPONSE_FRAMING_PATTERN =
  /\b(CognitiveBiomarkers|ClinicalTrajectory|CognitiveAnomaly|MovingBaseline|allostatic\s+overload|health[- ]monitor)/i;

const PUBLIC_ROUTE_ROOT = join(process.cwd(), "app/api");
const PUBLIC_TYPES_ROOTS = [
  join(process.cwd(), "types"),
  join(process.cwd(), "../../packages/shared/types"),
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
  const files = [
    ...collectTypeScriptFiles(PUBLIC_ROUTE_ROOT),
    ...PUBLIC_TYPES_ROOTS.flatMap((root) => collectTypeScriptFiles(root)),
  ];

  for (const filePath of files) {
    if (filePath.includes("src/internal/clinical")) continue;
    const source = readFileSync(filePath, "utf8");
    failures.push(...auditFile(relative(process.cwd(), filePath), source));
  }

  return { failures };
}
