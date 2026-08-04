import assert from "node:assert/strict";
import test from "node:test";

import {
  EXPECTED_ACCOUNT_HEADER,
  EXPECTED_ARCHIVE_HEADER,
  OWNER_SCOPE_MISMATCH,
  checkOwnerScope,
  readOwnerScopeClaim,
} from "../lib/server/owner-scope";

function requestWith(headers: Record<string, string>): Request {
  return new Request("https://example.test/api/sync/push", {
    method: "POST",
    headers,
  });
}

test("a request declaring another account is rejected", () => {
  const rejection = checkOwnerScope(
    { expectedAccountId: "account-a", expectedArchiveId: "archive-a" },
    "account-b",
  );

  assert.ok(rejection);
  assert.equal(rejection.code, OWNER_SCOPE_MISMATCH);
  assert.equal(rejection.status, 409);
  assert.equal(rejection.log.archiveScoped, true);
});

test("a request declaring the authenticated account is accepted", () => {
  assert.equal(
    checkOwnerScope({ expectedAccountId: "account-b" }, "account-b"),
    null,
  );
});

test("a request declaring nothing stays constrained by the session alone", () => {
  assert.equal(checkOwnerScope({}, "account-b"), null);
  assert.equal(checkOwnerScope({ expectedAccountId: "  " }, "account-b"), null);
});

test("headers take precedence over the body binding", () => {
  const claim = readOwnerScopeClaim(
    requestWith({
      [EXPECTED_ACCOUNT_HEADER]: "account-a",
      [EXPECTED_ARCHIVE_HEADER]: "archive-a",
    }),
    { expectedAccountId: "account-b" },
  );

  assert.equal(claim.expectedAccountId, "account-a");
  assert.equal(claim.expectedArchiveId, "archive-a");
  assert.ok(checkOwnerScope(claim, "account-b"));
});

test("a forged owner claim cannot widen scope", () => {
  // The client says it is account-a; the session says account-b. The session
  // is authoritative and the request is refused rather than silently rescoped.
  const claim = readOwnerScopeClaim(requestWith({}), {
    expectedAccountId: "account-a",
  });
  const rejection = checkOwnerScope(claim, "account-b");

  assert.ok(rejection);
  assert.equal(rejection.code, OWNER_SCOPE_MISMATCH);
});

test("the rejection carries metadata only", () => {
  const rejection = checkOwnerScope(
    { expectedAccountId: "account-a" },
    "account-b",
  );

  assert.ok(rejection);
  const serialized = JSON.stringify(rejection);
  assert.equal(serialized.includes("account-a"), false);
  assert.equal(serialized.includes("account-b"), false);
});
