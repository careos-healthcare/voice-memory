/**
 * Lulu print-job helpers. Sandbox unless LULU_ENV=production.
 * Keys: LULU_CLIENT_KEY, LULU_CLIENT_SECRET.
 *
 * book_orders stores only id, status, and created_at. PDF bytes stay in the
 * pending checkout until payment, then go to Lulu and are deleted there
 * after production when the API allows it.
 */

export const LULU_BLEED_INCHES = 0.125;
export const LULU_SPINE_INCHES_PER_PAGE = 0.002252;
export const BOOK_MARGIN_BPS = 2000;

export const PRINT_CONSENT_COPY =
  "To print your book, the PDF (your entries and photos in this date range) is sent to Lulu, our printer. It's deleted after printing.";

export class BookConsentRequired extends Error {
  constructor() {
    super("consent_required");
  }
}

export function luluApiBase(env = process.env.LULU_ENV): string {
  return env === "production" ? "https://api.lulu.com" : "https://api.sandbox.lulu.com";
}

/** Cover width in inches: two trim widths, the spine, and bleed on both edges. */
export function luluCoverWidthInches(pageCount: number, trimWidthInches: number): number {
  const spine = pageCount * LULU_SPINE_INCHES_PER_PAGE;
  const width = trimWidthInches * 2 + spine + LULU_BLEED_INCHES * 2;
  return Math.round(width * 10000) / 10000;
}

export function coverWidthFromDimensions(body: {
  width?: string | number;
}): number | null {
  if (body.width == null) return null;
  const width = typeof body.width === "number" ? body.width : Number(body.width);
  return Number.isFinite(width) ? width : null;
}

export function trimWidthInches(size: string): number {
  return size === "us_trade" ? 6 : 5.83;
}

export type PrintedBookQuote = {
  pageCount: number;
  coverWidthInches: number;
  printCostCents: number;
  shippingCents: number;
  marginCents: number;
  totalCents: number;
};

export function quotePrintedBook(input: {
  pageCount: number;
  trimWidthInches: number;
  printCostCents: number;
  shippingCents: number;
}): PrintedBookQuote {
  const marginCents = Math.round(
    ((input.printCostCents + input.shippingCents) * BOOK_MARGIN_BPS) / 10000,
  );
  return {
    pageCount: input.pageCount,
    coverWidthInches: luluCoverWidthInches(input.pageCount, input.trimWidthInches),
    printCostCents: input.printCostCents,
    shippingCents: input.shippingCents,
    marginCents,
    totalCents: input.printCostCents + input.shippingCents + marginCents,
  };
}

export type BookOrderRow = {
  id: string;
  status: string;
  created_at: string;
};

export type PendingPrintedBook = {
  pageCount: number;
  trimWidthInches: number;
  binding: string;
};

export type PaidCheckout = {
  id: string;
  payment_status?: string;
  metadata?: Record<string, string | undefined>;
};

export class BookOrderLedger {
  readonly rows: BookOrderRow[] = [];
  private readonly pending = new Map<string, PendingPrintedBook>();

  stageCheckout(sessionId: string, book: PendingPrintedBook): void {
    this.pending.set(sessionId, book);
  }

  find(id: string): BookOrderRow | undefined {
    return this.rows.find((row) => row.id === id);
  }

  /**
   * Inserts a book_orders row only after Stripe reports a paid checkout.
   * Returns null when payment has not been confirmed.
   */
  async fulfillAfterPayment(
    session: PaidCheckout,
    place: (book: PendingPrintedBook) => Promise<{ id: string }>,
    deleteFiles?: (orderId: string) => Promise<boolean>,
    now = new Date(),
  ): Promise<BookOrderRow | null> {
    if (session.metadata?.kind !== "printed_book") return null;
    if (session.payment_status !== "paid") return null;
    const book = this.pending.get(session.id);
    if (!book) return null;
    const placed = await place(book);
    const row: BookOrderRow = {
      id: placed.id,
      status: "created",
      created_at: now.toISOString(),
    };
    this.rows.push(row);
    this.pending.delete(session.id);
    if (deleteFiles) await deleteFiles(placed.id);
    return row;
  }
}

export function assertBookUploadConsent(consent: unknown): void {
  if (consent !== true) throw new BookConsentRequired();
}

export function preparePrintedBookCheckout(body: {
  consent?: unknown;
  pageCount?: number;
  size?: string;
  binding?: string;
}): { sessionId: string; book: PendingPrintedBook; orderPlaced: false } {
  assertBookUploadConsent(body.consent);
  const pageCount = body.pageCount ?? 0;
  if (!Number.isInteger(pageCount) || pageCount < 1) {
    throw new Error("page_count_required");
  }
  const book: PendingPrintedBook = {
    pageCount,
    trimWidthInches: trimWidthInches(body.size ?? "a5"),
    binding: body.binding === "hardcover" ? "hardcover" : "paperback",
  };
  return {
    sessionId: `pending_${pageCount}_${book.binding}`,
    book,
    orderPlaced: false,
  };
}

let ledger = new BookOrderLedger();

export function bookOrderLedger(): BookOrderLedger {
  return ledger;
}

export function resetBookOrderLedger(): BookOrderLedger {
  ledger = new BookOrderLedger();
  return ledger;
}
