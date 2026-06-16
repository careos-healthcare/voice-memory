import "server-only";

import {
  getDatabaseDiagnostics,
  shouldUsePostgresStorage,
} from "@/lib/server/db";

export interface AuthEnvFlags {
  nodeEnv: string;
  databaseUrlPresent: boolean;
  authSecretPresent: boolean;
  resendApiKeyPresent: boolean;
  emailFromPresent: boolean;
  postgresStorage: boolean;
}

export function readAuthEnvFlags(): AuthEnvFlags {
  return {
    nodeEnv: process.env.NODE_ENV ?? "unknown",
    databaseUrlPresent: Boolean(process.env.DATABASE_URL?.trim()),
    authSecretPresent: Boolean(process.env.AUTH_SECRET?.trim()),
    resendApiKeyPresent: Boolean(process.env.RESEND_API_KEY?.trim()),
    emailFromPresent: Boolean(process.env.EMAIL_FROM?.trim()),
    postgresStorage: shouldUsePostgresStorage(),
  };
}

export function logAuthEvent(
  route: string,
  payload: Record<string, unknown>,
  level: "info" | "error" = "info",
): void {
  const line = JSON.stringify({
    route,
    ...readAuthEnvFlags(),
    ...getDatabaseDiagnostics(),
    ...payload,
  });
  if (level === "error") {
    console.error("[ArchiveMe auth]", line);
  } else {
    console.info("[ArchiveMe auth]", line);
  }
}

export function logAuthError(
  route: string,
  error: unknown,
  extra: Record<string, unknown> = {},
): void {
  const err = error instanceof Error ? error : new Error(String(error));
  logAuthEvent(
    route,
    {
      ok: false,
      message: err.message,
      stack: err.stack ?? null,
      errorName: err.name,
      ...extra,
    },
    "error",
  );
}

export function isPostgresAuthError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  const message = error.message.toLowerCase();
  return (
    message.includes("database_url") ||
    message.includes("econnrefused") ||
    message.includes("enotfound") ||
    message.includes("ENOENT") ||
    message.includes("auth_codes") ||
    message.includes("sessions") ||
    message.includes("relation") ||
    message.includes("ssl") ||
    message.includes("password authentication") ||
    message.includes("no pg_hba") ||
    error.name === "AggregateError"
  );
}
