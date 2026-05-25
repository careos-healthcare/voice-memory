import { SyncClientError } from "@/lib/sync/sync-errors";
import { syncWarn } from "@/lib/sync/sync-log";
import type { SyncErrorCode } from "@/types/sync-errors";

export interface SyncApiEnvelope {
  ok: boolean;
  error?: string;
  code?: string;
}

export type SyncPullPayload = SyncApiEnvelope & {
  blobs?: Array<{
    id: string;
    type: string;
    encrypted: { ciphertext: string; iv: string; version: number };
    updatedAt: string;
    byteLength: number;
  }>;
};

export type SyncPushPayload = SyncApiEnvelope & {
  manifest?: unknown;
};

export type SyncManifestPayload = SyncApiEnvelope & {
  manifest?: {
    userId: string;
    version: number;
    updatedAt: string;
    blobs: Array<{ id: string; type: string; updatedAt: string; byteLength: number }>;
  };
};

export async function readResponseText(response: Response): Promise<string> {
  try {
    return await response.text();
  } catch {
    return "";
  }
}

export function isJsonResponse(response: Response, text: string): boolean {
  const contentType = response.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) return true;
  if (contentType.includes("text/html")) return false;
  const trimmed = text.trim();
  return trimmed.startsWith("{") || trimmed.startsWith("[");
}

export function parseJsonText<T>(text: string, fallback: T): { data: T; parseError: SyncClientError | null } {
  if (!text.trim()) {
    return {
      data: fallback,
      parseError: new SyncClientError("EMPTY_REMOTE_PAYLOAD", "Remote backup response was empty."),
    };
  }

  try {
    return { data: JSON.parse(text) as T, parseError: null };
  } catch {
    return {
      data: fallback,
      parseError: new SyncClientError("INVALID_REMOTE_JSON", "Remote backup response was invalid."),
    };
  }
}

export async function readResponseJson<T>(
  response: Response,
  fallback: T,
  options: { routeLabel?: string; requireOk?: boolean } = {},
): Promise<T> {
  const text = await readResponseText(response);
  const routeLabel = options.routeLabel ?? "sync";

  if (!isJsonResponse(response, text)) {
    syncWarn(`${routeLabel}: non-JSON response`, {
      status: response.status,
      contentType: response.headers.get("content-type"),
      length: text.length,
    });
    throw new SyncClientError("NON_JSON_RESPONSE", "Remote backup response was invalid.");
  }

  const { data, parseError } = parseJsonText(text, fallback);
  if (parseError) {
    syncWarn(`${routeLabel}: empty or invalid JSON`, {
      status: response.status,
      length: text.length,
    });
    throw parseError;
  }

  const envelope = data as SyncApiEnvelope;
  if (options.requireOk !== false && envelope && typeof envelope === "object" && "ok" in envelope) {
    if (envelope.ok === false) {
      const code = (envelope.code ?? "SYNC_PULL_FAILED") as SyncErrorCode;
      throw new SyncClientError(
        code,
        envelope.error ?? "Remote backup response was invalid.",
      );
    }
  }

  if (!response.ok) {
    const code = ((data as SyncApiEnvelope).code ?? inferHttpErrorCode(routeLabel)) as SyncErrorCode;
    throw new SyncClientError(
      code,
      (data as SyncApiEnvelope).error ?? `Sync request failed (${response.status}).`,
    );
  }

  return data;
}

function inferHttpErrorCode(routeLabel: string): SyncErrorCode {
  if (routeLabel.includes("push")) return "SYNC_PUSH_FAILED";
  if (routeLabel.includes("manifest")) return "SYNC_MANIFEST_FAILED";
  return "SYNC_PULL_FAILED";
}
