import "server-only";

import type { SyncApiRoute } from "@/types/sync-errors";

export interface SyncRouteLogContext {
  requestId: string;
  route: SyncApiRoute;
  method: string;
  emailHash: string | null;
  contentLength: number | null;
  bodyPresent: boolean;
  parseSuccess: boolean | null;
  responseShape: string | null;
  encryptionVersions: number[];
  blobCount: number;
  blobIds: string[];
  changeCount?: number;
  ok: boolean;
  errorCode: string | null;
}

function newRequestId(): string {
  return `sync_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export function createSyncRouteLog(route: SyncApiRoute, method: string): {
  requestId: string;
  log: (patch: Partial<SyncRouteLogContext>) => void;
} {
  const requestId = newRequestId();
  let context: SyncRouteLogContext = {
    requestId,
    route,
    method,
    emailHash: null,
    contentLength: null,
    bodyPresent: false,
    parseSuccess: null,
    responseShape: null,
    encryptionVersions: [],
    blobCount: 0,
    blobIds: [],
    ok: false,
    errorCode: null,
  };

  return {
    requestId,
    log(patch) {
      context = { ...context, ...patch };
      console.info("[ArchiveMe sync]", JSON.stringify(context));
    },
  };
}

export function readContentLength(request: Request): number | null {
  const raw = request.headers.get("content-length");
  if (!raw) return null;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : null;
}

export async function readRequestBodyText(request: Request): Promise<string> {
  try {
    return await request.text();
  } catch {
    return "";
  }
}

export function parseRequestJson<T>(raw: string): { data: T | null; success: boolean } {
  if (!raw.trim()) return { data: null, success: false };
  try {
    return { data: JSON.parse(raw) as T, success: true };
  } catch {
    return { data: null, success: false };
  }
}

export function summarizeBlobs(
  blobs: Array<{ id?: string; encrypted?: { version?: number } }> | undefined,
): Pick<SyncRouteLogContext, "blobCount" | "blobIds" | "encryptionVersions"> {
  const list = blobs ?? [];
  return {
    blobCount: list.length,
    blobIds: list.map((blob) => blob.id ?? "unknown").slice(0, 12),
    encryptionVersions: [
      ...new Set(
        list
          .map((blob) => blob.encrypted?.version)
          .filter((version): version is number => typeof version === "number"),
      ),
    ],
  };
}
