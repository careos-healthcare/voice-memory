import { createHash } from "crypto";

import type { ArchiveSynthesisPack } from "@/types/archive-synthesis";

/** Stable hash for cache keys — excludes client-supplied archiveHash if present. */
export function computeArchiveHashFromPack(pack: ArchiveSynthesisPack): string {
  const { ...body } = pack;
  const canonical = JSON.stringify(sortKeys(body));
  return createHash("sha256").update(canonical).digest("hex").slice(0, 32);
}

function sortKeys(value: unknown): unknown {
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(sortKeys);
  const obj = value as Record<string, unknown>;
  const sorted: Record<string, unknown> = {};
  for (const key of Object.keys(obj).sort()) {
    sorted[key] = sortKeys(obj[key]);
  }
  return sorted;
}

export function synthesisCacheKey(
  subject: string,
  monthKey: string,
  archiveHash: string,
): string {
  return `${subject}:${monthKey}:${archiveHash}`;
}
