import "server-only";

import { hashUserIdForAudit } from "@/lib/server/auth-crypto";

/** Field names never emitted in structured logs. */
export const REDACTED_LOG_FIELD_NAMES = [
  "raw_text",
  "audio_bytes",
  "transcript",
  "embedding",
  "citedEntryIds",
  "lexicalDiversity",
  "cohesionDrift",
  "emotionalVolatility",
  "biomarkers",
  "clinicalTrajectory",
  "cognitiveBaseline",
  "overloadState",
  "allostaticOverload",
  "diagnosticScore",
  "healthMonitoring",
] as const;

/** Detects clinical quarantine module paths in log strings (stack traces, err messages). */
export const CLINICAL_MODULE_PATH_PATTERN =
  /src\/internal\/clinical(?:\/|$)|clinical_trajectory_history_store|cognitive_anomaly_detector|moving_baseline_calculator|cognitive_biomarkers/i;

/** Keys suggesting clinical/diagnostic payload fields in structured logs. */
export const CLINICAL_QUARANTINE_KEY_PATTERN =
  /biomarker|clinical|allostatic|cognitive_?anomaly|moving_?baseline|overload_?state|diagnostic_?score|health_?monitor/i;

const REDACTED_FIELD_PATTERN = new RegExp(
  `^(${REDACTED_LOG_FIELD_NAMES.join("|")})$`,
  "i",
);

const LEGACY_BANNED_KEY_PATTERN =
  /transcript|journal|payload|audio_bytes|reflection|email_body|embedding|raw_text|citedEntryIds|biomarker|clinical|allostatic|overload|diagnostic|health_?monitor/i;

export const SENSITIVE_USER_ID_LOG_PATH_PREFIXES = [
  "/api/insights",
  "/api/live-audio/ws",
] as const;

export function shouldMaskUserIdInRequestLog(pathname: string): boolean {
  return SENSITIVE_USER_ID_LOG_PATH_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
  );
}

/** Deterministic, non-reversible audit hash for request logs. */
export function hashUserIdForRequestLog(userId: string): string {
  return hashUserIdForAudit(userId);
}

export function maskUserIdForSensitiveRequestLog(
  pathname: string,
  userId: string | null | undefined,
): string | undefined {
  if (!userId?.trim()) return undefined;
  if (!shouldMaskUserIdInRequestLog(pathname)) return userId;
  return hashUserIdForRequestLog(userId);
}

export function maskRateLimitSubjectForRequestLog(
  pathname: string,
  subject: string | null | undefined,
): string | undefined {
  if (!subject) return undefined;
  if (!shouldMaskUserIdInRequestLog(pathname)) return subject;
  if (subject.startsWith("user:")) {
    const userId = subject.slice("user:".length);
    return `user:${hashUserIdForRequestLog(userId)}`;
  }
  return subject;
}

export function extractUserIdFromSubject(subject: string | undefined): string | undefined {
  if (!subject?.startsWith("user:")) return undefined;
  const userId = subject.slice("user:".length).trim();
  return userId || undefined;
}

function redactValue(key: string): string {
  if (REDACTED_FIELD_PATTERN.test(key)) {
    return "[REDACTED]";
  }
  return "[REDACTED]";
}

export function containsClinicalQuarantineReference(value: string): boolean {
  return CLINICAL_MODULE_PATH_PATTERN.test(value);
}

function sanitizeClinicalString(value: string, key?: string): unknown {
  if (containsClinicalQuarantineReference(value)) {
    return {
      clinicalQuarantine: true,
      value: "[CLINICAL_QUARANTINE]",
    };
  }
  if (key && CLINICAL_QUARANTINE_KEY_PATTERN.test(key)) {
    return "[REDACTED]";
  }
  if (typeof value === "string" && value.length > 200) {
    return `${value.slice(0, 80)}…[truncated]`;
  }
  return value;
}

/**
 * Deep-scrubs log objects — drops legacy banned keys and replaces sensitive
 * field values with `[REDACTED]`.
 */
export function sanitizeLogRecord(
  value: unknown,
  key?: string,
): unknown {
  if (value === null || value === undefined) return value;

  if (typeof value === "string") {
    return sanitizeClinicalString(value, key);
  }

  if (Array.isArray(value)) {
    return value.map((entry) => sanitizeLogRecord(entry));
  }

  if (typeof value === "object") {
    const out: Record<string, unknown> = {};
    let clinicalFlag = false;

    for (const [entryKey, entryValue] of Object.entries(value as Record<string, unknown>)) {
      if (LEGACY_BANNED_KEY_PATTERN.test(entryKey) || REDACTED_FIELD_PATTERN.test(entryKey)) {
        out[entryKey] = redactValue(entryKey);
        continue;
      }

      if (typeof entryValue === "string" && containsClinicalQuarantineReference(entryValue)) {
        clinicalFlag = true;
        out[entryKey] = "[CLINICAL_QUARANTINE]";
        continue;
      }

      out[entryKey] = sanitizeLogRecord(entryValue, entryKey);
    }

    if (clinicalFlag) {
      out.clinicalQuarantine = true;
    }
    return out;
  }

  if (key && REDACTED_FIELD_PATTERN.test(key)) {
    return redactValue(key);
  }

  return value;
}

export function prepareSensitiveRequestLogFields(input: {
  pathname: string;
  method?: string;
  subject?: string;
  userId?: string;
  sessionId?: string;
  statusCode?: number;
  extra?: Record<string, unknown>;
}): Record<string, unknown> {
  const userId =
    input.userId ?? extractUserIdFromSubject(input.subject);

  const base: Record<string, unknown> = {
    method: input.method,
    path: input.pathname,
    subject: maskRateLimitSubjectForRequestLog(input.pathname, input.subject),
    userHash: maskUserIdForSensitiveRequestLog(input.pathname, userId),
    sessionId: input.sessionId,
    statusCode: input.statusCode,
    ...input.extra,
  };

  if (!shouldMaskUserIdInRequestLog(input.pathname)) {
    base.userId = userId;
  }

  return sanitizeLogRecord(base) as Record<string, unknown>;
}

/** Pino-compatible redaction path list. */
export function pinoRedactPaths(): string[] {
  const paths = new Set<string>();
  for (const field of REDACTED_LOG_FIELD_NAMES) {
    paths.add(field);
    paths.add(`*.${field}`);
    paths.add(`*.*.${field}`);
    paths.add(`req.body.${field}`);
    paths.add(`req.headers.${field}`);
    paths.add(`res.body.${field}`);
    paths.add(`payload.${field}`);
    paths.add(`data.${field}`);
  }
  paths.add("clinicalQuarantine");
  paths.add("*.clinicalQuarantine");
  paths.add("userId");
  paths.add("req.body.userId");
  paths.add("body.userId");
  return [...paths];
}

/** JSON request log for shared runtime paths (WebSocket upgrade, etc.). */
export function emitSanitizedRequestLog(
  message: string,
  fields: Record<string, unknown>,
): void {
  const payload = sanitizeLogRecord({
    ts: new Date().toISOString(),
    level: "info",
    component: "http",
    msg: message,
    ...fields,
  });
  console.info(JSON.stringify(payload));
}
