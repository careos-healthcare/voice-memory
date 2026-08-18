import { createHash } from "node:crypto";

/** E2E/test-only — never honored in production unless VOICEMEMORY_E2E_TEST_MODE=1. */
export const VOICEMEMORY_TEST_IP_HEADER = "x-voicememory-test-ip";

const TEST_IP_MAX_LEN = 128;
const TEST_IP_PATTERN = /^[\w.\-:]+$/;

export function isE2eTestIpHeaderAllowed(): boolean {
  if (process.env.NODE_ENV !== "production") return true;
  return process.env.VOICEMEMORY_E2E_TEST_MODE === "1";
}

function testIpFromRequest(request: Request): string | null {
  if (!isE2eTestIpHeaderAllowed()) return null;
  const raw = request.headers.get(VOICEMEMORY_TEST_IP_HEADER)?.trim();
  if (!raw || raw.length > TEST_IP_MAX_LEN || !TEST_IP_PATTERN.test(raw)) {
    return null;
  }
  return raw;
}

export function clientIpFromRequest(request: Request): string {
  const testIp = testIpFromRequest(request);
  if (testIp) return testIp;

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
