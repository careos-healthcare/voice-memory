import {
  isJsonResponse,
  parseJsonText,
  readResponseJson,
  readResponseText,
} from "@/lib/sync/parse-response";
import { SyncClientError } from "@/lib/sync/sync-errors";
import {
  isRecoverableRemoteCorruption,
  recoverFromCorruptRemoteState,
} from "@/lib/sync/sync-recovery";
import { validateEncryptedEnvelope, validateRemoteBlobRecord } from "@/lib/sync/validate-remote";
import type { EncryptedPayload } from "@/types/sync";

export interface SyncParseTestResult {
  scenario: string;
  passed: boolean;
  failedAssertions: string[];
}

export interface SyncParseTestReport {
  results: SyncParseTestResult[];
  allPassed: boolean;
  failed: number;
}

function assert(condition: boolean, message: string, failures: string[]): void {
  if (!condition) failures.push(message);
}

function mockResponse(input: {
  status?: number;
  contentType?: string;
  body: string;
}): Response {
  return new Response(input.body, {
    status: input.status ?? 200,
    headers: input.contentType ? { "content-type": input.contentType } : undefined,
  });
}

async function testEmptyManifestResponse(failures: string[]): Promise<void> {
  const response = mockResponse({ body: "", contentType: "application/json" });
  const text = await readResponseText(response);
  assert(text === "", "empty body text", failures);

  const parsed = parseJsonText<{ ok: boolean }>(text, { ok: true });
  assert(parsed.parseError?.code === "EMPTY_REMOTE_PAYLOAD", "empty parse code", failures);

  try {
    await readResponseJson(response, { ok: true }, { routeLabel: "sync/manifest" });
    assert(false, "empty manifest should throw", failures);
  } catch (error) {
    assert(
      error instanceof SyncClientError && error.code === "EMPTY_REMOTE_PAYLOAD",
      "empty manifest throws SyncClientError",
      failures,
    );
  }
}

async function testHtmlErrorPage(failures: string[]): Promise<void> {
  const response = mockResponse({
    body: "<!DOCTYPE html><html><body>502 Bad Gateway</body></html>",
    contentType: "text/html",
  });

  assert(!isJsonResponse(response, await readResponseText(response)), "html is not json", failures);

  try {
    await readResponseJson(response, { ok: true, blobs: [] }, { routeLabel: "sync/pull" });
    assert(false, "html response should throw", failures);
  } catch (error) {
    assert(
      error instanceof SyncClientError && error.code === "NON_JSON_RESPONSE",
      "html throws NON_JSON_RESPONSE",
      failures,
    );
  }
}

function testTruncatedEncryptedPayload(failures: string[]): void {
  const truncated: EncryptedPayload = {
    version: 1,
    iv: "YWJj",
    ciphertext: "!!!not-base64!!!",
  };
  const validation = validateEncryptedEnvelope(truncated);
  assert(!validation.valid, "truncated ciphertext invalid", failures);
  assert(
    validation.issues.some((issue) => issue.code === "INVALID_ENCRYPTED_ENVELOPE"),
    "truncated maps to INVALID_ENCRYPTED_ENVELOPE",
    failures,
  );
}

function testMalformedCiphertext(failures: string[]): void {
  const empty: EncryptedPayload = { version: 1, iv: "", ciphertext: "" };
  const validation = validateEncryptedEnvelope(empty);
  assert(!validation.valid, "empty envelope invalid", failures);
  assert(
    validation.issues.some((issue) => issue.code === "EMPTY_REMOTE_PAYLOAD"),
    "empty ciphertext code",
    failures,
  );
}

function testMissingBlob(failures: string[]): void {
  const validation = validateRemoteBlobRecord({
    id: "",
    updatedAt: "not-a-date",
    encrypted: undefined,
  });
  assert(!validation.valid, "missing blob invalid", failures);
  assert(validation.issues.length >= 2, "missing blob has multiple issues", failures);
}

function testRecoveryAfterRemoteCorruption(failures: string[]): void {
  const codes = [
    "EMPTY_REMOTE_PAYLOAD",
    "INVALID_REMOTE_JSON",
    "INVALID_ENCRYPTED_ENVELOPE",
    "DECRYPT_FAILED",
    "NON_JSON_RESPONSE",
  ] as const;

  for (const code of codes) {
    const error = new SyncClientError(code, "test");
    assert(isRecoverableRemoteCorruption(error), `recoverable: ${code}`, failures);
  }

  assert(
    !isRecoverableRemoteCorruption(new SyncClientError("SYNC_AUTH_REQUIRED", "auth")),
    "auth errors not recoverable",
    failures,
  );

  recoverFromCorruptRemoteState("test_recovery");
}

async function testValidJsonEnvelope(failures: string[]): Promise<void> {
  const response = mockResponse({
    body: JSON.stringify({ ok: true, blobs: [] }),
    contentType: "application/json",
  });
  const data = await readResponseJson<{ ok: boolean; blobs: unknown[] }>(
    response,
    { ok: false, blobs: [] },
    { routeLabel: "sync/pull" },
  );
  assert(data.ok === true && Array.isArray(data.blobs), "valid pull json parsed", failures);
}

async function runAllSyncParseTestsAsync(): Promise<SyncParseTestReport> {
  const results: SyncParseTestResult[] = [];

  async function runScenario(name: string, fn: (failures: string[]) => void | Promise<void>) {
    const failures: string[] = [];
    try {
      await fn(failures);
    } catch (error) {
      failures.push(error instanceof Error ? error.message : String(error));
    }
    results.push({ scenario: name, passed: failures.length === 0, failedAssertions: failures });
  }

  await runScenario("empty manifest response", testEmptyManifestResponse);
  await runScenario("html error page response", testHtmlErrorPage);
  await runScenario("truncated encrypted payload", (f) => testTruncatedEncryptedPayload(f));
  await runScenario("malformed ciphertext envelope", (f) => testMalformedCiphertext(f));
  await runScenario("missing remote blob record", (f) => testMissingBlob(f));
  await runScenario("recovery after remote corruption", (f) => testRecoveryAfterRemoteCorruption(f));
  await runScenario("valid json pull envelope", testValidJsonEnvelope);

  return finalizeReport(results);
}

function finalizeReport(results: SyncParseTestResult[]): SyncParseTestReport {
  const failed = results.filter((result) => !result.passed).length;
  return { results, allPassed: failed === 0, failed };
}

export async function runSyncParseTestsForCi(): Promise<SyncParseTestReport> {
  return runAllSyncParseTestsAsync();
}
