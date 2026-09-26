import { NextResponse } from "next/server";

import {
  coverWidthFromDimensions,
  luluApiBase,
  luluCoverWidthInches,
  quotePrintedBook,
  trimWidthInches,
} from "@/lib/server/printed-books";

export const runtime = "nodejs";

type QuoteBody = {
  pageCount?: number;
  size?: string;
  binding?: string;
  printCostCents?: number;
  shippingCents?: number;
};

async function coverWidthFromLulu(pageCount: number, trimWidth: number): Promise<number> {
  const key = process.env.LULU_CLIENT_KEY;
  const secret = process.env.LULU_CLIENT_SECRET;
  if (!key || !secret) return luluCoverWidthInches(pageCount, trimWidth);
  const tokenResponse = await fetch(
    `${luluApiBase()}/auth/realms/glasstree/protocol/openid-connect/token`,
    {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "client_credentials",
        client_id: key,
        client_secret: secret,
      }),
    },
  );
  if (!tokenResponse.ok) return luluCoverWidthInches(pageCount, trimWidth);
  const token = (await tokenResponse.json()) as { access_token?: string };
  if (!token.access_token) return luluCoverWidthInches(pageCount, trimWidth);
  const dimensions = await fetch(
    `${luluApiBase()}/cover-dimensions/?interior_page_count=${pageCount}&unit=inch`,
    { headers: { authorization: `Bearer ${token.access_token}` } },
  );
  if (!dimensions.ok) return luluCoverWidthInches(pageCount, trimWidth);
  const body = (await dimensions.json()) as { width?: string | number };
  return coverWidthFromDimensions(body) ?? luluCoverWidthInches(pageCount, trimWidth);
}

export async function POST(request: Request) {
  const body = (await request.json()) as QuoteBody;
  const pageCount = body.pageCount ?? 0;
  if (!Number.isInteger(pageCount) || pageCount < 1) {
    return NextResponse.json({ error: "page_count_required" }, { status: 400 });
  }
  const trim = trimWidthInches(body.size ?? "a5");
  const coverWidthInches = await coverWidthFromLulu(pageCount, trim);
  const quote = quotePrintedBook({
    pageCount,
    trimWidthInches: trim,
    printCostCents: body.printCostCents ?? 1200,
    shippingCents: body.shippingCents ?? 450,
  });
  return NextResponse.json({ ...quote, coverWidthInches });
}
