import assert from "node:assert/strict";

import {
  isValidDeviceId,
  signCaptureToken,
  verifyCaptureToken,
} from "@/lib/capture/capture-token";

export function runApiGuardTests(): { passed: number; failures: string[] } {
  const failures: string[] = [];

  function check(name: string, fn: () => void): void {
    try {
      fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  check("valid device id", () => {
    assert.equal(isValidDeviceId("550e8400-e29b-41d4-a716-446655440000"), true);
    assert.equal(isValidDeviceId("not-a-uuid"), false);
  });

  check("capture token roundtrip with binding", () => {
    const binding = { ipHash: "ip-test-hash", uaHash: "ua-test-hash" };
    const token = signCaptureToken("550e8400-e29b-41d4-a716-446655440000", binding);
    const payload = verifyCaptureToken(token, binding);
    assert.ok(payload);
    assert.equal(payload?.deviceId, "550e8400-e29b-41d4-a716-446655440000");
    assert.ok(payload?.jti);
  });

  check("reject wrong binding", () => {
    const binding = { ipHash: "ip-a", uaHash: "ua-a" };
    const token = signCaptureToken("550e8400-e29b-41d4-a716-446655440000", binding);
    assert.equal(
      verifyCaptureToken(token, { ipHash: "ip-b", uaHash: "ua-a" }),
      null,
    );
  });

  check("reject tampered token", () => {
    const token = signCaptureToken("550e8400-e29b-41d4-a716-446655440000");
    assert.equal(verifyCaptureToken(`${token}x`), null);
  });

  return { passed: 4 - failures.length, failures };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const result = runApiGuardTests();
  if (result.failures.length > 0) {
    console.error("api-guard-tests failed:\n", result.failures.join("\n"));
    process.exit(1);
  }
  console.log("api-guard-tests ok");
}
