import assert from "node:assert/strict";

import {
  containsClinicalQuarantineReference,
  hashUserIdForRequestLog,
  prepareSensitiveRequestLogFields,
  sanitizeLogRecord,
  shouldMaskUserIdInRequestLog,
} from "@/lib/server/log-sanitizer";

export async function runLoggerSanitizationTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  try {
    const sanitized = sanitizeLogRecord({
      transcript: "secret words",
      raw_text: "ledger chunk",
      audio_bytes: Buffer.from("pcm"),
      embedding: [0.1, 0.2],
      citedEntryIds: ["entry-1"],
      ok: true,
    }) as Record<string, unknown>;

    for (const key of ["transcript", "raw_text", "audio_bytes", "embedding", "citedEntryIds"]) {
      if (sanitized[key] !== "[REDACTED]") {
        failures.push(`sanitizeLogRecord did not redact ${key}`);
      }
    }
    if (sanitized.ok !== true) {
      failures.push("sanitizeLogRecord dropped allowed fields");
    }
  } catch (error) {
    failures.push(`sanitizeLogRecord threw: ${error}`);
  }

  try {
    const userId = "user-abc-123";
    const fields = prepareSensitiveRequestLogFields({
      pathname: "/api/insights/evidence",
      method: "POST",
      userId,
    }) as Record<string, unknown>;

    if (fields.userId !== undefined) {
      failures.push("sensitive insights route leaked raw userId");
    }
    if (fields.userHash !== hashUserIdForRequestLog(userId)) {
      failures.push("sensitive insights route missing deterministic userHash");
    }
    if (!shouldMaskUserIdInRequestLog("/api/live-audio/ws")) {
      failures.push("live-audio ws path not marked sensitive");
    }
  } catch (error) {
    failures.push(`prepareSensitiveRequestLogFields threw: ${error}`);
  }

  try {
    const masked = prepareSensitiveRequestLogFields({
      pathname: "/api/health",
      userId: "user-open",
    }) as Record<string, unknown>;
    assert.equal(masked.userId, "user-open");
  } catch (error) {
    failures.push(`non-sensitive route masking failed: ${error}`);
  }

  try {
    const sanitized = sanitizeLogRecord({
      biomarkers: {
        lexicalDiversity: 0.5,
        cohesionDrift: 0.2,
        emotionalVolatility: 0.7,
      },
      message: "fault in src/internal/clinical/cognitive_anomaly_detector.ts",
      ok: true,
    }) as Record<string, unknown>;

    if (sanitized.biomarkers !== "[REDACTED]") {
      failures.push("sanitizeLogRecord did not redact biomarkers");
    }
    if (sanitized.clinicalQuarantine !== true) {
      failures.push("sanitizeLogRecord did not flag clinicalQuarantine");
    }
    if (
      !containsClinicalQuarantineReference(
        "src/internal/clinical/moving_baseline_calculator",
      )
    ) {
      failures.push("containsClinicalQuarantineReference missed module path");
    }
  } catch (error) {
    failures.push(`clinical log sanitization failed: ${error}`);
  }

  return { failures };
}
