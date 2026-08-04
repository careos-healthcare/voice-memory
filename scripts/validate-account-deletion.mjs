#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs/promises";

import { DATABASE_SCHEMA_STATEMENTS } from "../lib/server/db.ts";
import { runAccountDeletionExternalAdapter } from "../lib/server/account-deletion.ts";
import {
  EXTERNAL_DELETION_PROCESSORS,
  REGISTERED_USER_LINKED_TABLES,
  USER_DATA_DELETION_REGISTRY,
} from "../lib/server/privacy/user-data-deletion-registry.ts";

const lifecycleTables = new Set([
  "account_deletion_requests",
  "account_deletion_outbox",
  "account_deletion_receipts",
]);
const linkedColumns = /\b(user_id|normalized_email|subject_key)\b|^\s*email text/m;
const runtimeLinkedTables = new Set();

for (const statement of DATABASE_SCHEMA_STATEMENTS) {
  const match = statement.match(/CREATE TABLE IF NOT EXISTS\s+([a-z0-9_]+)/i);
  if (match && linkedColumns.test(statement) && !lifecycleTables.has(match[1])) {
    runtimeLinkedTables.add(match[1]);
  }
}

const registered = new Set(REGISTERED_USER_LINKED_TABLES);
const missing = [...runtimeLinkedTables].filter((table) => !registered.has(table));
assert.deepEqual(missing, [], `Unregistered user-linked runtime tables: ${missing.join(", ")}`);
assert.equal(USER_DATA_DELETION_REGISTRY[0]?.id, "sessions", "sessions must be revoked first");

for (const processor of EXTERNAL_DELETION_PROCESSORS) {
  if (processor.mappingTable) {
    assert(
      registered.has(processor.mappingTable),
      `${processor.id} mapping table is not locally registered`,
    );
  }
}

const calls = [];
const fakeQuery = async (sql, params = []) => {
  calls.push({ sql, params });
  assert(!sql.includes("user-fixture"), "a user identifier was interpolated into SQL");
  if (/SELECT count\(\*\)|AS remaining/i.test(sql)) {
    return { rowCount: 1, rows: [{ remaining: 0 }] };
  }
  return { rowCount: 1, rows: [{ delete_user_unit_economics: 1 }] };
};
const context = {
  userId: "user-fixture",
  normalizedEmail: "fixture@example.invalid",
  subjectKey: "user:user-fixture",
  economicsSubjectKeys: ["ue:v1:fixture", "ue:v2:fixture"],
  syncDirectory: null,
  storageMode: "postgres",
  query: fakeQuery,
  async deleteLocal() { return 0; },
  async verifyLocal() { return true; },
};
for (const resource of USER_DATA_DELETION_REGISTRY) {
  await resource.handler(context);
  assert.equal(await resource.verifier(context), true, `${resource.id} verifier failed`);
}
assert(calls.length >= USER_DATA_DELETION_REGISTRY.length * 2 - 2);

const adapterCalls = [];
const fakeAdapters = {
  async deleteStripeCustomer(value) {
    adapterCalls.push(["stripe", value]);
    return "complete";
  },
  async deleteRevenueCatSubscriber(value) {
    adapterCalls.push(["revenuecat", value]);
    return "blocked";
  },
};
assert.equal(
  await runAccountDeletionExternalAdapter("stripe-customer", "cus_fixture", fakeAdapters),
  "complete",
);
assert.equal(
  await runAccountDeletionExternalAdapter(
    "revenuecat-subscriber",
    "subscriber_fixture",
    fakeAdapters,
  ),
  "blocked",
);
assert.deepEqual(adapterCalls, [
  ["stripe", "cus_fixture"],
  ["revenuecat", "subscriber_fixture"],
]);

const migration = await fs.readFile(
  new URL("../docs/sql/009_account_deletion.sql", import.meta.url),
  "utf8",
);
for (const table of lifecycleTables) {
  assert(migration.includes(table), `SQL mirror missing ${table}`);
}
assert(migration.includes("delete_user_unit_economics"));

console.log(
  JSON.stringify({
    validation: "account-deletion",
    registryResources: USER_DATA_DELETION_REGISTRY.length,
    coveredRuntimeTables: runtimeLinkedTables.size,
    externalProcessors: EXTERNAL_DELETION_PROCESSORS.length,
    ok: true,
  }),
);
