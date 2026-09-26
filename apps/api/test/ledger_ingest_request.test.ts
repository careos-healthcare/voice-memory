import assert from "node:assert/strict";
import test from "node:test";

import { parseLedgerIngestBody } from "../src/services/ledger/ingest_request.ts";

test("ledger ingest accepts an entry id and transcript", () => {
  assert.deepEqual(
    parseLedgerIngestBody({
      entryId: " entry-1 ",
      transcript: " I mentioned the river. ",
    }),
    { entryId: "entry-1", transcript: "I mentioned the river." },
  );
});

test("ledger ingest rejects an empty transcript", () => {
  assert.equal(parseLedgerIngestBody({ entryId: "entry-1", transcript: "  " }), null);
  assert.equal(parseLedgerIngestBody(null), null);
});
