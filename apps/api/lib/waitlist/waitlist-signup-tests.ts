import assert from "node:assert/strict";
import test from "node:test";

import {
  WAITLIST_IP_MAX,
  resetWaitlistIpBucketsForTest,
  signupForWaitlist,
  type WaitlistStore,
} from "../../../../packages/shared/lib/waitlist/signup.ts";

function memoryStore(): WaitlistStore & { rows: Map<string, string>; inserts: number } {
  const rows = new Map<string, string>();
  return {
    rows,
    inserts: 0,
    async insert(email, token) {
      this.inserts += 1;
      if (rows.has(email)) return "duplicate";
      rows.set(email, token);
      return "created";
    },
  };
}

test("closes the waitlist on September 30", async () => {
  resetWaitlistIpBucketsForTest();
  const store = memoryStore();
  const result = await signupForWaitlist({
    email: "late@example.com",
    ip: "203.0.113.30",
    nowMs: Date.UTC(2026, 8, 30),
    store,
  });
  assert.equal(result.status, 403);
  assert.equal(store.rows.size, 0);
});

test("rejects an invalid email", async () => {
  resetWaitlistIpBucketsForTest();
  const store = memoryStore();
  const result = await signupForWaitlist({
    email: "not-an-email",
    ip: "203.0.113.10",
    store,
  });
  assert.equal(result.status, 400);
  assert.equal(store.rows.size, 0);
});

test("rate-limits repeated sign-ups from one IP", async () => {
  resetWaitlistIpBucketsForTest();
  const store = memoryStore();
  const ip = "203.0.113.20";
  for (let i = 0; i < WAITLIST_IP_MAX; i += 1) {
    const result = await signupForWaitlist({
      email: `person${i}@example.com`,
      ip,
      store,
    });
    assert.equal(result.status, 200);
  }
  const blocked = await signupForWaitlist({
    email: "one-more@example.com",
    ip,
    store,
  });
  assert.equal(blocked.status, 429);
  assert.equal(store.rows.has("one-more@example.com"), false);
});

test("duplicate email returns 200 without a second row", async () => {
  resetWaitlistIpBucketsForTest();
  const store = memoryStore();
  let sent = 0;
  const first = await signupForWaitlist({
    email: "Ada@Example.com",
    ip: "203.0.113.30",
    store,
    sendConfirmation: async () => {
      sent += 1;
    },
  });
  const second = await signupForWaitlist({
    email: "ada@example.com",
    ip: "203.0.113.31",
    store,
    sendConfirmation: async () => {
      sent += 1;
    },
  });
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.equal(store.rows.size, 1);
  assert.equal(sent, 1);
});
