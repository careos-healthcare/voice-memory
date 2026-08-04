import { ECONOMICS_SUBJECT_KEY } from "@/lib/server/unit-economics-route";

export type FinanceRevenueProvider = "stripe" | "revenuecat";

export interface FinanceRevenueInput {
  subjectKey: string;
  provider: FinanceRevenueProvider;
  metric: "revenue" | "adjustments";
  amountMicroUsd: bigint;
  occurredAt: Date;
  externalEventToken: string;
}

const INTEGER = /^-?(0|[1-9][0-9]*)$/;
const ALLOWED_KEYS = new Set([
  "subjectKey",
  "provider",
  "metric",
  "amountMicroUsd",
  "occurredAt",
  "externalEventToken",
]);

export function parseFinanceRevenueInput(
  value: unknown,
): { ok: true; input: FinanceRevenueInput } | { ok: false; code: string } {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return { ok: false, code: "INVALID_REQUEST" };
  }
  const body = value as Record<string, unknown>;
  if (Object.keys(body).some((key) => !ALLOWED_KEYS.has(key))) {
    return { ok: false, code: "UNSUPPORTED_FIELD" };
  }
  if (
    typeof body.subjectKey !== "string" ||
    !ECONOMICS_SUBJECT_KEY.test(body.subjectKey)
  ) {
    return { ok: false, code: "INVALID_SUBJECT_KEY" };
  }
  if (body.provider !== "stripe" && body.provider !== "revenuecat") {
    return { ok: false, code: "INVALID_PROVIDER" };
  }
  if (body.metric !== "revenue" && body.metric !== "adjustments") {
    return { ok: false, code: "INVALID_METRIC" };
  }
  if (
    typeof body.amountMicroUsd !== "string" ||
    !INTEGER.test(body.amountMicroUsd)
  ) {
    return { ok: false, code: "INVALID_AMOUNT" };
  }
  const amountMicroUsd = BigInt(body.amountMicroUsd);
  if (
    amountMicroUsd < -9_223_372_036_854_775_808n ||
    amountMicroUsd > 9_223_372_036_854_775_807n
  ) {
    return { ok: false, code: "INVALID_AMOUNT" };
  }
  if (body.metric === "revenue" && amountMicroUsd < 0n) {
    return { ok: false, code: "INVALID_AMOUNT" };
  }
  if (
    typeof body.occurredAt !== "string" ||
    !body.occurredAt.trim()
  ) {
    return { ok: false, code: "INVALID_OCCURRED_AT" };
  }
  const occurredAt = new Date(body.occurredAt);
  if (Number.isNaN(occurredAt.getTime())) {
    return { ok: false, code: "INVALID_OCCURRED_AT" };
  }
  if (
    typeof body.externalEventToken !== "string" ||
    body.externalEventToken.trim().length < 1 ||
    body.externalEventToken.length > 512
  ) {
    return { ok: false, code: "INVALID_EVENT_TOKEN" };
  }
  return {
    ok: true,
    input: {
      subjectKey: body.subjectKey,
      provider: body.provider,
      metric: body.metric,
      amountMicroUsd,
      occurredAt,
      externalEventToken: body.externalEventToken.trim(),
    },
  };
}
