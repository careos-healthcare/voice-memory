import assert from "node:assert/strict";
import test from "node:test";

import {
  clearUserLedger,
  deleteLedgerRow,
  upsertLedgerRow,
  type LedgerMemoryRow,
} from "../src/services/ledger/ledger_memory.ts";

const rows: LedgerMemoryRow[] = [
  { userId: "person-a", entryId: "1", rawText: "I walked by the river." },
  { userId: "person-a", entryId: "2", rawText: "The kitchen was quiet." },
  { userId: "person-b", entryId: "3", rawText: "Someone else's note." },
];

test("delete my cloud copy clears that person's ledger", () => {
  const left = clearUserLedger(rows, "person-a");
  assert.deepEqual(
    left.map((row) => row.entryId),
    ["3"],
  );
});

test("ingest replaces an existing entry instead of adding a second row", () => {
  const once = upsertLedgerRow(rows, {
    userId: "person-a",
    entryId: "1",
    rawText: "I walked by the river again.",
  });
  const matches = once.filter(
    (row) => row.userId === "person-a" && row.entryId === "1",
  );
  assert.equal(matches.length, 1);
  assert.equal(matches[0]?.rawText, "I walked by the river again.");
});

test("deleting one entry leaves the rest of the ledger", () => {
  const left = deleteLedgerRow(rows, "person-a", "1");
  assert.deepEqual(
    left.map((row) => `${row.userId}:${row.entryId}`),
    ["person-a:2", "person-b:3"],
  );
});
