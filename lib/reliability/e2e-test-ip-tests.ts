import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

import { isValidDeviceId } from "@/lib/capture/capture-token";
import {
  clientIpFromRequest,
  ipHashFromRequest,
  isE2eTestIpHeaderAllowed,
  VOICEMEMORY_TEST_IP_HEADER,
} from "@/lib/capture/request-ip";
import { checkAndRecordApiUsage } from "@/lib/server/api-usage-store";

async function withEnv(
  patch: Record<string, string | undefined>,
  fn: () => void | Promise<void>,
): Promise<void> {
  const prev: Record<string, string | undefined> = {};
  for (const key of Object.keys(patch)) {
    prev[key] = process.env[key];
    const v = patch[key];
    if (v === undefined) delete process.env[key];
    else process.env[key] = v;
  }
  try {
    await fn();
  } finally {
    for (const key of Object.keys(patch)) {
      const v = prev[key];
      if (v === undefined) delete process.env[key];
      else process.env[key] = v;
    }
  }
}

export async function runE2eTestIpTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("development honors x-voicememory-test-ip", async () => {
    await withEnv({ NODE_ENV: "development", VOICEMEMORY_E2E_TEST_MODE: undefined }, () => {
      assert.equal(isE2eTestIpHeaderAllowed(), true);
      const req = new Request("http://localhost/", {
        headers: { [VOICEMEMORY_TEST_IP_HEADER]: "dev-test-ip-1" },
      });
      assert.equal(clientIpFromRequest(req), "dev-test-ip-1");
    });
  });

  await check("production ignores test IP without E2E flag", async () => {
    await withEnv({ NODE_ENV: "production", VOICEMEMORY_E2E_TEST_MODE: undefined }, () => {
      assert.equal(isE2eTestIpHeaderAllowed(), false);
      const req = new Request("http://localhost/", {
        headers: { [VOICEMEMORY_TEST_IP_HEADER]: "spoof-attacker" },
      });
      assert.equal(clientIpFromRequest(req), "unknown");
    });
  });

  await check("production honors test IP when VOICEMEMORY_E2E_TEST_MODE=1", async () => {
    await withEnv({ NODE_ENV: "production", VOICEMEMORY_E2E_TEST_MODE: "1" }, () => {
      assert.equal(isE2eTestIpHeaderAllowed(), true);
      const req = new Request("http://localhost/", {
        headers: { [VOICEMEMORY_TEST_IP_HEADER]: "e2e-isolated-ip" },
      });
      assert.equal(clientIpFromRequest(req), "e2e-isolated-ip");
    });
  });

  await check("isolated test IP gets fresh attest rate-limit bucket", async () => {
    await withEnv({ NODE_ENV: "production", VOICEMEMORY_E2E_TEST_MODE: "1" }, async () => {
      const req = new Request("http://localhost/", {
        headers: { [VOICEMEMORY_TEST_IP_HEADER]: `unit-attest-${randomUUID()}` },
      });
      const subject = `ip:${ipHashFromRequest(req)}`;
      const usage = await checkAndRecordApiUsage(subject, "attest");
      assert.equal(usage.allowed, true);
    });
  });

  await check("invalid deviceId rejected by attest validation", () => {
    assert.equal(isValidDeviceId("not-a-uuid"), false);
    assert.equal(isValidDeviceId(randomUUID()), true);
  });

  return { failures };
}
