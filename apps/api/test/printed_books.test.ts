import assert from "node:assert/strict";
import test from "node:test";

import {
  BookConsentRequired,
  BookOrderLedger,
  assertBookUploadConsent,
  luluCoverWidthInches,
  preparePrintedBookCheckout,
  quotePrintedBook,
} from "../../../packages/shared/lib/server/printed-books.ts";

test("cover width is both trim widths, the spine, and bleed", () => {
  assert.equal(luluCoverWidthInches(100, 6), 12.4752);
  assert.equal(luluCoverWidthInches(24, 5.83), 11.964);
});

test("a quote uses the pdf page count", () => {
  const pdfPageCount = 32;
  const quote = quotePrintedBook({
    pageCount: pdfPageCount,
    trimWidthInches: 6,
    printCostCents: 1000,
    shippingCents: 400,
  });
  assert.equal(quote.pageCount, pdfPageCount);
  assert.equal(quote.coverWidthInches, luluCoverWidthInches(pdfPageCount, 6));
  assert.equal(quote.totalCents, quote.printCostCents + quote.shippingCents + quote.marginCents);
});

test("an order row is created only after the paid webhook", async () => {
  const ledger = new BookOrderLedger();
  const prepared = preparePrintedBookCheckout({
    consent: true,
    pageCount: 32,
    size: "us_trade",
    binding: "paperback",
  });
  ledger.stageCheckout("cs_test", prepared.book);
  assert.equal(ledger.rows.length, 0);

  const unpaid = await ledger.fulfillAfterPayment(
    {
      id: "cs_test",
      payment_status: "unpaid",
      metadata: { kind: "printed_book" },
    },
    async () => ({ id: "should-not-place" }),
  );
  assert.equal(unpaid, null);
  assert.equal(ledger.rows.length, 0);

  let placed = false;
  let deleted = false;
  const row = await ledger.fulfillAfterPayment(
    {
      id: "cs_test",
      payment_status: "paid",
      metadata: { kind: "printed_book" },
    },
    async () => {
      placed = true;
      return { id: "lulu_1" };
    },
    async () => {
      deleted = true;
      return true;
    },
  );
  assert.equal(placed, true);
  assert.equal(deleted, true);
  assert.equal(ledger.rows.length, 1);
  assert.equal(row?.id, "lulu_1");
  assert.equal(row?.status, "created");
  assert.ok(row?.created_at);
});

test("consent is required before a checkout is prepared", () => {
  assert.throws(() => assertBookUploadConsent(false), BookConsentRequired);
  assert.throws(
    () => preparePrintedBookCheckout({ consent: false, pageCount: 12 }),
    BookConsentRequired,
  );
  const prepared = preparePrintedBookCheckout({ consent: true, pageCount: 12 });
  assert.equal(prepared.orderPlaced, false);
});
