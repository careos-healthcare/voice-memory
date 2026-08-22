import "server-only";

import pino from "pino";

import {
  emitSanitizedRequestLog,
  pinoRedactPaths,
  prepareSensitiveRequestLogFields,
  sanitizeLogRecord,
  shouldMaskUserIdInRequestLog,
} from "@/lib/server/log-sanitizer";

const level = process.env.LOG_LEVEL?.trim() || (process.env.NODE_ENV === "production" ? "info" : "debug");

export const logger = pino({
  level,
  name: "archiveme-api",
  redact: {
    paths: pinoRedactPaths(),
    censor: "[REDACTED]",
  },
  formatters: {
    level(label) {
      return { level: label };
    },
  },
  serializers: {
    err: pino.stdSerializers.err,
    req(request: Record<string, unknown>) {
      return sanitizeLogRecord(request);
    },
    res(response: Record<string, unknown>) {
      return sanitizeLogRecord(response);
    },
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});

export const requestLogger = logger.child({ component: "http" });

export function logSanitized(level: "info" | "warn" | "error" | "debug", fields: Record<string, unknown>, message: string) {
  const payload = sanitizeLogRecord(fields) as Record<string, unknown>;
  requestLogger[level](payload, message);
}

export function logIncomingHttpRequest(input: {
  method?: string | null;
  pathname: string;
  subject?: string;
  userId?: string;
  statusCode?: number;
}) {
  const fields = prepareSensitiveRequestLogFields({
    pathname: input.pathname,
    method: input.method ?? undefined,
    subject: input.subject,
    userId: input.userId,
    statusCode: input.statusCode,
  });

  requestLogger.info(
    {
      ...fields,
      sensitiveRoute: shouldMaskUserIdInRequestLog(input.pathname),
    },
    "incoming_request",
  );
}

export function logIncomingWebSocketRequest(input: {
  pathname: string;
  subject?: string;
  userId?: string;
  sessionId?: string;
  accepted: boolean;
  code?: string;
}) {
  emitSanitizedRequestLog(
    "incoming_websocket_request",
    prepareSensitiveRequestLogFields({
      pathname: input.pathname,
      method: "GET",
      subject: input.subject,
      userId: input.userId,
      sessionId: input.sessionId,
      extra: {
        upgrade: "websocket",
        accepted: input.accepted,
        code: input.code,
        sensitiveRoute: shouldMaskUserIdInRequestLog(input.pathname),
      },
    }),
  );
}
