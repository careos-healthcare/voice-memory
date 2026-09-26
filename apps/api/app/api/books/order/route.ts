import { NextResponse } from "next/server";

import { getStripeBillingConfig } from "@/lib/billing/stripe-config";
import { requireStripeClient } from "@/lib/server/stripe-client";
import {
  BookConsentRequired,
  bookOrderLedger,
  preparePrintedBookCheckout,
  quotePrintedBook,
} from "@/lib/server/printed-books";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const body = (await request.json()) as {
    consent?: unknown;
    pageCount?: number;
    size?: string;
    binding?: string;
    printCostCents?: number;
    shippingCents?: number;
  };
  try {
    const prepared = preparePrintedBookCheckout(body);
    const quote = quotePrintedBook({
      pageCount: prepared.book.pageCount,
      trimWidthInches: prepared.book.trimWidthInches,
      printCostCents: body.printCostCents ?? 1200,
      shippingCents: body.shippingCents ?? 450,
    });
    const ledger = bookOrderLedger();
    let sessionId = prepared.sessionId;
    let url: string | null = null;
    const config = getStripeBillingConfig();
    if (config.enabled) {
      const stripe = requireStripeClient();
      const checkout = await stripe.checkout.sessions.create({
        mode: "payment",
        line_items: [
          {
            price_data: {
              currency: "usd",
              unit_amount: quote.totalCents,
              product_data: { name: "Printed book" },
            },
            quantity: 1,
          },
        ],
        success_url: `${config.appUrl}/?book=success`,
        cancel_url: `${config.appUrl}/?book=cancel`,
        metadata: {
          kind: "printed_book",
          pageCount: String(prepared.book.pageCount),
          binding: prepared.book.binding,
        },
      });
      sessionId = checkout.id;
      url = checkout.url;
    }
    ledger.stageCheckout(sessionId, prepared.book);
    return NextResponse.json({
      sessionId,
      url,
      orderPlaced: false,
    });
  } catch (error) {
    if (error instanceof BookConsentRequired) {
      return NextResponse.json({ error: "consent_required" }, { status: 400 });
    }
    return NextResponse.json({ error: "book_order_failed" }, { status: 400 });
  }
}
