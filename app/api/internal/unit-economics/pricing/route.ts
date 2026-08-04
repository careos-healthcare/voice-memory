import { NextResponse } from "next/server";

import { authorizeInternalPushApi } from "@/lib/push/internal-api-auth";
import {
  COGS_CATEGORIES,
  UNIT_ECONOMICS_METRICS,
  UNIT_ECONOMICS_RESOURCES,
  type PriceLine,
} from "@/lib/server/unit-economics-domain";
import { insertPricingCatalog } from "@/lib/server/unit-economics-pricing-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const INTEGER = /^(0|[1-9][0-9]*)$/;

export async function POST(request: Request) {
  const auth = await authorizeInternalPushApi(request);
  if (!auth.authorized) return auth.response;
  let body: {
    versionKey?: unknown;
    effectiveFrom?: unknown;
    effectiveTo?: unknown;
    lines?: unknown;
  };
  try {
    body = await request.json() as typeof body;
  } catch {
    return NextResponse.json({ error: "Invalid request.", code: "INVALID_JSON" }, { status: 400 });
  }
  if (
    typeof body.versionKey !== "string" ||
    typeof body.effectiveFrom !== "string" ||
    (body.effectiveTo !== null && body.effectiveTo !== undefined &&
      typeof body.effectiveTo !== "string") ||
    !Array.isArray(body.lines) ||
    body.lines.length < 1 ||
    body.lines.length > 100
  ) {
    return NextResponse.json({ error: "Invalid catalog.", code: "INVALID_CATALOG" }, { status: 400 });
  }
  const effectiveFrom = new Date(body.effectiveFrom);
  const effectiveTo = body.effectiveTo ? new Date(body.effectiveTo) : null;
  const lines: PriceLine[] = [];
  for (const value of body.lines) {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      return invalidLine();
    }
    const line = value as Record<string, unknown>;
    if (
      typeof line.metric !== "string" ||
      !UNIT_ECONOMICS_METRICS.includes(line.metric as never) ||
      ["revenue", "credits", "adjustments"].includes(line.metric) ||
      typeof line.resource !== "string" ||
      !UNIT_ECONOMICS_RESOURCES.includes(line.resource as never) ||
      typeof line.cogsCategory !== "string" ||
      !COGS_CATEGORIES.includes(line.cogsCategory as never) ||
      (line.costBasis !== "exact" && line.costBasis !== "estimated") ||
      typeof line.unitQuantity !== "string" ||
      !INTEGER.test(line.unitQuantity) ||
      line.unitQuantity === "0" ||
      typeof line.unitPriceMicroUsd !== "string" ||
      !INTEGER.test(line.unitPriceMicroUsd)
    ) {
      return invalidLine();
    }
    lines.push({
      versionKey: body.versionKey,
      metric: line.metric as PriceLine["metric"],
      resource: line.resource as PriceLine["resource"],
      cogsCategory: line.cogsCategory as PriceLine["cogsCategory"],
      unitQuantity: BigInt(line.unitQuantity),
      unitPriceMicroUsd: BigInt(line.unitPriceMicroUsd),
      costBasis: line.costBasis,
    });
  }
  try {
    const inserted = await insertPricingCatalog({
      versionKey: body.versionKey,
      effectiveFrom,
      effectiveTo,
      lines,
    });
    return NextResponse.json({ ok: true, inserted, versionKey: body.versionKey }, {
      status: inserted ? 201 : 200,
    });
  } catch {
    return NextResponse.json(
      { error: "Catalog rejected.", code: "CATALOG_REJECTED" },
      { status: 409 },
    );
  }
}

function invalidLine() {
  return NextResponse.json({ error: "Invalid price line.", code: "INVALID_PRICE_LINE" }, {
    status: 400,
  });
}
