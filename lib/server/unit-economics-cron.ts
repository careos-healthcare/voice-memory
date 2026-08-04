import { createHash, timingSafeEqual } from "node:crypto";

function digest(value: string): Buffer {
  return createHash("sha256").update(value, "utf8").digest();
}

export function authorizeUnitEconomicsCron(
  authorization: string | null,
  configuredSecret = process.env.CRON_SECRET,
): boolean {
  const secret = configuredSecret?.trim();
  if (!secret) return false;
  const prefix = "Bearer ";
  if (!authorization?.startsWith(prefix)) return false;
  const supplied = authorization.slice(prefix.length);
  return timingSafeEqual(digest(supplied), digest(secret));
}
