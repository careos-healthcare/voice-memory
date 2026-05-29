import { createHash } from "node:crypto";

/** Privacy-safe hashes for server persistence — never store raw quotes or names. */
export function hashResurfacingKey(raw: string): string {
  const normalized = raw
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 80);
  if (!normalized) return "";
  return createHash("sha256").update(normalized).digest("hex").slice(0, 24);
}

export function evidenceClusterHash(parts: {
  phraseKeyHash?: string;
  topicHash?: string;
  personHash?: string;
}): string {
  const payload = [parts.phraseKeyHash ?? "", parts.topicHash ?? "", parts.personHash ?? ""].join(
    "|",
  );
  if (!payload.replace(/\|/g, "")) return "";
  return createHash("sha256").update(payload).digest("hex").slice(0, 24);
}
