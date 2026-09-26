import assert from "node:assert/strict";
import test from "node:test";

import {
  ledgerLabelPattern,
  parseLedgerEntityDelete,
} from "../src/services/ledger/entity_request.ts";

test("entity delete accepts a trimmed label", () => {
  assert.deepEqual(parseLedgerEntityDelete({ label: " river " }), {
    label: "river",
  });
  assert.equal(ledgerLabelPattern("river"), "%river%");
  assert.equal(ledgerLabelPattern("100%"), "%100\\%%");
});

test("entity delete rejects a short or empty label", () => {
  assert.equal(parseLedgerEntityDelete({ label: "a" }), null);
  assert.equal(parseLedgerEntityDelete({ label: "  " }), null);
  assert.equal(parseLedgerEntityDelete(null), null);
});
