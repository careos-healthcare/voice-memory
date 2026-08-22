import assert from "node:assert/strict";

import {
  containsClinicalQuarantineReference,
  sanitizeLogRecord,
} from "@/lib/server/log-sanitizer";

import { auditPublicApiClinicalSurface } from "./audit-public-surface";

export async function runClinicalQuarantineAuditTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  try {
    const audit = auditPublicApiClinicalSurface();
    failures.push(...audit.failures);
  } catch (error) {
    failures.push(`auditPublicApiClinicalSurface threw: ${error}`);
  }

  try {
    const sanitized = sanitizeLogRecord({
      lexicalDiversity: 0.42,
      cohesionDrift: 0.18,
      biomarkers: { emotionalVolatility: 0.5 },
      stack: "Error at src/internal/clinical/cognitive_anomaly_detector.ts:12",
      ok: true,
    }) as Record<string, unknown>;

    for (const key of ["lexicalDiversity", "cohesionDrift", "biomarkers"]) {
      if (sanitized[key] !== "[REDACTED]") {
        failures.push(`clinical field ${key} was not redacted in logs`);
      }
    }

    if (sanitized.clinicalQuarantine !== true) {
      failures.push("clinical module reference was not flagged in logs");
    }

    assert.equal(
      containsClinicalQuarantineReference(
        "loaded src/internal/clinical/moving_baseline_calculator.ts",
      ),
      true,
    );
    assert.equal(containsClinicalQuarantineReference("/api/health"), false);
  } catch (error) {
    failures.push(`clinical log sanitization test failed: ${error}`);
  }

  return { failures };
}
