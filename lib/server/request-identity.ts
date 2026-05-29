import "server-only";

import { createHash } from "node:crypto";

export function clientIpFromRequest(request: Request): string {
  return (
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    request.headers.get("x-real-ip")?.trim() ??
    "unknown"
  );
}

export function hashRequestIdentity(value: string): string {
  return createHash("sha256").update(value).digest("hex").slice(0, 32);
}

export function ipHashFromRequest(request: Request): string {
  return hashRequestIdentity(clientIpFromRequest(request));
}

export function userAgentHashFromRequest(request: Request): string {
  const ua = request.headers.get("user-agent") ?? "unknown";
  return hashRequestIdentity(ua);
}
