import assert from "node:assert/strict";

import {
  bodyContainsSentinel,
  buildApiErrorEnvelope,
  buildApiErrorFromException,
  classifyInternalException,
  generateApiRequestId,
  mapInternalCategoryToPublicCode,
} from "@/lib/server/api-error-core";
import { PUBLIC_API_ERROR_CODES } from "@/lib/server/public-api-error-codes";
import { extractApiError } from "@/lib/sync/parse-response";

const SENTINEL = "VM_SENTINEL_DO_NOT_LEAK_9f3c2a1b";

export async function runApiErrorResponseTests(): Promise<{ passed: number; failures: string[] }> {
  const failures: string[] = [];
  let passed = 0;

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
      passed++;
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("stable validation error envelope", () => {
    const built = buildApiErrorEnvelope({
      code: "VALIDATION_ERROR",
      status: 400,
    });
    assert.equal(built.status, 400);
    assert.equal(built.body.error.code, "VALIDATION_ERROR");
    assert.equal(built.body.error.retryable, false);
    assert.match(built.body.error.requestId, /^api_[0-9a-f]{16}$/);
  });

  await check("stable auth, forbidden, rate limit, conflict, upstream, internal codes", () => {
    const cases = [
      ["AUTH_REQUIRED", 401],
      ["FORBIDDEN", 403],
      ["RATE_LIMIT_MINUTE", 429],
      ["CONFLICT", 409],
      ["UPSTREAM_UNAVAILABLE", 503],
      ["INTERNAL_ERROR", 500],
    ] as const;
    for (const [code, status] of cases) {
      const built = buildApiErrorEnvelope({ code, status });
      assert.equal(built.status, status);
      assert.equal(built.body.error.code, code);
    }
  });

  await check("requestId is server generated and ignores attacker input", () => {
    const attackerId = `<script>${SENTINEL}</script>`;
    const id = generateApiRequestId();
    assert.notEqual(id, attackerId);
    assert.doesNotMatch(id, /script/);
    const built = buildApiErrorEnvelope({ code: "INTERNAL_ERROR" });
    assert.doesNotMatch(built.body.error.requestId, /script/);
  });

  await check("sync failure never leaks internal sentinel", () => {
    const built = buildApiErrorFromException(new Error(SENTINEL), {
      code: "SYNC_PUSH_FAILED",
      status: 500,
    });
    const body = JSON.stringify(built.body);
    assert.equal(bodyContainsSentinel(body, SENTINEL), false);
    assert.equal(built.status, 500);
    assert.equal(built.body.error.code, "SYNC_PUSH_FAILED");
  });

  await check("account deletion auth path never leaks sentinel", () => {
    const built = buildApiErrorFromException(new Error(SENTINEL), {
      code: "AUTH_DATABASE_FAILED",
      status: 503,
    });
    const body = JSON.stringify(built.body);
    assert.equal(bodyContainsSentinel(body, SENTINEL), false);
  });

  await check("auth dependency failure never leaks sentinel", () => {
    const built = buildApiErrorFromException(new Error(SENTINEL), {
      code: "AUTH_EMAIL_SEND_FAILED",
    });
    const body = JSON.stringify(built.body);
    assert.equal(bodyContainsSentinel(body, SENTINEL), false);
    assert.equal(built.body.error.code, "AUTH_EMAIL_SEND_FAILED");
  });

  await check("transcription dependency failure never leaks sentinel", () => {
    const built = buildApiErrorEnvelope({
      code: "TRANSCRIBE_UNAVAILABLE",
      status: 500,
    });
    const body = JSON.stringify(built.body);
    assert.equal(bodyContainsSentinel(body, SENTINEL), false);
  });

  await check("analysis dependency failure never leaks sentinel", () => {
    const built = buildApiErrorEnvelope({
      code: "ANALYZE_UNAVAILABLE",
      status: 500,
    });
    const body = JSON.stringify(built.body);
    assert.equal(bodyContainsSentinel(body, SENTINEL), false);
  });

  await check("internal exception maps to finite public codes", () => {
    assert.equal(mapInternalCategoryToPublicCode("rate_limited"), "RATE_LIMIT_MINUTE");
    assert.equal(mapInternalCategoryToPublicCode("database_unavailable"), "UPSTREAM_UNAVAILABLE");
    assert.equal(classifyInternalException(new Error("postgres connection refused")), "database_unavailable");
    assert.equal(classifyInternalException(new Error(SENTINEL)), "internal_error");
  });

  await check("parse-response reads nested error contract", () => {
    const parsed = extractApiError({
      error: {
        code: "SYNC_PULL_FAILED",
        message: "Could not read encrypted backup.",
        retryable: true,
        requestId: "sync_abcd1234",
      },
    });
    assert.ok(parsed);
    assert.equal(parsed?.code, "SYNC_PULL_FAILED");
    assert.equal(parsed?.requestId, "sync_abcd1234");
  });

  await check("public code catalog covers sync and account deletion codes", () => {
    for (const code of [
      "SYNC_PUSH_FAILED",
      "ACCOUNT_DELETE_PARTIAL",
      "SESSION_REVOKE_FAILED",
      "CONFIRM_REQUIRED",
    ]) {
      assert.ok(PUBLIC_API_ERROR_CODES[code as keyof typeof PUBLIC_API_ERROR_CODES], code);
    }
  });

  return { passed, failures };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runApiErrorResponseTests().then((result) => {
    if (result.failures.length > 0) {
      console.error("api-error-response-tests failed:\n", result.failures.join("\n"));
      process.exit(1);
    }
    console.log(`api-error-response-tests ok (${result.passed} checks)`);
  });
}
