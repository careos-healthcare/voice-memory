import "server-only";

import { createHash } from "node:crypto";

export function hashEmailForLog(email: string): string {
  return createHash("sha256").update(email.trim().toLowerCase()).digest("hex").slice(0, 16);
}

export interface AuthSendCodeLogContext {
  requestId: string;
  route: "send-code";
  method: string;
  emailHash: string | null;
  resendInitialized: boolean | null;
  emailFromPresent: boolean | null;
  apiKeyPresent: boolean | null;
  appUrlPresent: boolean | null;
  resendResponseId: string | null;
  resendErrorName: string | null;
  resendErrorMessage: string | null;
  ok: boolean;
  errorCode: string | null;
  stack: string | null;
}

function newRequestId(): string {
  return `auth_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export function createAuthSendCodeLog(): {
  requestId: string;
  log: (patch: Partial<AuthSendCodeLogContext>) => void;
  finalize: (error?: unknown) => void;
} {
  const requestId = newRequestId();
  let context: AuthSendCodeLogContext = {
    requestId,
    route: "send-code",
    method: "POST",
    emailHash: null,
    resendInitialized: null,
    emailFromPresent: null,
    apiKeyPresent: null,
    appUrlPresent: null,
    resendResponseId: null,
    resendErrorName: null,
    resendErrorMessage: null,
    ok: false,
    errorCode: null,
    stack: null,
  };

  const log = (patch: Partial<AuthSendCodeLogContext>) => {
    context = { ...context, ...patch };
    console.info("[ArchiveMe auth]", JSON.stringify(context));
  };

  const finalize = (error?: unknown) => {
    if (error instanceof Error && !context.stack) {
      log({ stack: error.stack ?? error.message });
    }
    console.info("[ArchiveMe auth]", JSON.stringify(context));
  };

  return { requestId, log, finalize };
}
