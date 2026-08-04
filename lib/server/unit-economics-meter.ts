import { randomUUID } from "node:crypto";

import type { ApiGuardContext } from "@/lib/server/api-guard";
import {
  isUnitEconomicsEnabled,
  isUnitEconomicsPricingRequired,
} from "@/lib/server/unit-economics-config";
import {
  subjectKeyVersion,
  type MeasurementBasis,
  type UnitEconomicsDimensions,
  type UnitEconomicsMetric,
  type UnitEconomicsResource,
} from "@/lib/server/unit-economics-domain";
import {
  recordMoneyLedgerRow,
  recordPricedUsage,
} from "@/lib/server/unit-economics-engine";
import {
  createEconomicsOpaqueEventPart,
  createEconomicsSubjectKey,
} from "@/lib/server/unit-economics-subject-key";
import { commitUsageReservation } from "@/lib/server/usage-reservation-store";

type BillableMetric = Exclude<UnitEconomicsMetric, "revenue" | "credits" | "adjustments">;

export type RawEconomicsSubject =
  | { kind: "user"; id: string }
  | { kind: "device"; id: string };

export interface BestEffortMeterInput {
  operation: string;
  subject: RawEconomicsSubject | ApiGuardContext;
  idempotencyKey?: string;
  metric: BillableMetric;
  resource: UnitEconomicsResource;
  quantity: bigint | number;
  dimensions?: UnitEconomicsDimensions;
  occurredAt?: Date;
  measurementBasis: MeasurementBasis;
}

async function commitMonetizedUsage(
  subject: RawEconomicsSubject | ApiGuardContext,
  metric: BillableMetric,
  quantity: bigint,
): Promise<void> {
  if ("kind" in subject) return;
  const reservation = subject.monetization?.reservation;
  if (!reservation) return;
  if (
    reservation.meterId === "remoteTranscriptionSeconds" &&
    metric === "transcription_audio_milliseconds"
  ) {
    await commitUsageReservation(
      reservation.reservationId,
      Number((quantity + 999n) / 1_000n),
      {
        audioSeconds: Number((quantity + 999n) / 1_000n),
        safeResultCode: "provider_completed",
      },
    );
    return;
  }
  if (
    reservation.meterId !== "remoteTranscriptionSeconds" &&
    metric === "image_generations"
  ) {
    await commitUsageReservation(reservation.reservationId, 1, {
      safeResultCode: "provider_completed",
    });
  }
}

async function commitOpenAiChatReservation(
  subject: RawEconomicsSubject | ApiGuardContext,
  tokens: OpenAiTokenClasses,
): Promise<void> {
  if ("kind" in subject) return;
  const reservation = subject.monetization?.reservation;
  if (!reservation || reservation.meterId === "remoteTranscriptionSeconds") {
    return;
  }
  await commitUsageReservation(reservation.reservationId, 1, {
    providerInputUnits: tokens.input + tokens.cached,
    providerOutputUnits: tokens.output + tokens.reasoning,
    safeResultCode: "provider_completed",
  });
}

function rawSubject(
  subject: RawEconomicsSubject | ApiGuardContext,
): RawEconomicsSubject | null {
  if ("kind" in subject) return subject.id ? subject : null;
  if (subject.userId) return { kind: "user", id: subject.userId };
  if (subject.deviceId) return { kind: "device", id: subject.deviceId };
  return null;
}

function meteringErrorCode(error: unknown): string {
  if (!(error instanceof Error)) return "UNKNOWN";
  if (error.message.includes("pricing")) return "PRICING_UNAVAILABLE";
  if (error.message.includes("price line")) return "PRICE_LINE_UNAVAILABLE";
  if (error.message.includes("subject")) return "SUBJECT_INVALID";
  if (error.message.includes("quantity")) return "QUANTITY_INVALID";
  return "ACCOUNTING_FAILED";
}

function logMeteringFailure(operation: string, error: unknown): void {
  const errorCode = meteringErrorCode(error);
  let pricingRequired = false;
  try {
    pricingRequired = isUnitEconomicsPricingRequired();
  } catch {
    pricingRequired = true;
  }
  console.error(JSON.stringify({
    severity:
      pricingRequired &&
        (errorCode === "PRICING_UNAVAILABLE" || errorCode === "PRICE_LINE_UNAVAILABLE")
        ? "high"
        : "error",
    component: "unit_economics_accounting",
    operation,
    errorCode,
  }));
}

export async function meterBestEffort(input: BestEffortMeterInput): Promise<boolean> {
  let quantity: bigint;
  try {
    quantity =
      typeof input.quantity === "number" ? BigInt(input.quantity) : input.quantity;
    if (quantity < 0n) throw new Error("quantity invalid");
  } catch (error) {
    logMeteringFailure(input.operation, error);
    return false;
  }
  await commitMonetizedUsage(input.subject, input.metric, quantity);
  try {
    const subject = rawSubject(input.subject);
    if (!subject) throw new Error("subject unavailable");
    if (!isUnitEconomicsEnabled()) return false;
    const operationNonce = input.idempotencyKey?.trim() || randomUUID();
    const opaqueEventPart = createEconomicsOpaqueEventPart(operationNonce);
    return await recordPricedUsage({
      eventParts: [input.operation, opaqueEventPart, input.metric],
      subjectKey: createEconomicsSubjectKey(subject.kind, subject.id),
      metric: input.metric,
      resource: input.resource,
      quantity,
      dimensions: input.dimensions,
      occurredAt: input.occurredAt ?? new Date(),
      measurementBasis: input.measurementBasis,
    });
  } catch (error) {
    logMeteringFailure(input.operation, error);
    return false;
  }
}

export interface BestEffortMoneyInput {
  operation: string;
  subject:
    | RawEconomicsSubject
    | ApiGuardContext
    | { subjectKey: string };
  idempotencyKey: string;
  metric: "revenue" | "adjustments";
  amountMicroUsd: bigint;
  resource:
    | "stripe.subscription"
    | "revenuecat.subscription"
    | "adjustment.correction";
  dimensions?: UnitEconomicsDimensions;
  occurredAt?: Date;
}

function economicsSubjectKey(
  subject: BestEffortMoneyInput["subject"],
): string {
  if ("subjectKey" in subject) {
    subjectKeyVersion(subject.subjectKey);
    return subject.subjectKey;
  }
  const raw = rawSubject(subject);
  if (!raw) throw new Error("subject unavailable");
  return createEconomicsSubjectKey(raw.kind, raw.id);
}

/**
 * Returns true when the money row exists after the call, including an
 * idempotent duplicate. False means disabled or an accounting failure.
 */
export async function meterMoneyBestEffort(
  input: BestEffortMoneyInput,
): Promise<boolean> {
  if (!isUnitEconomicsEnabled()) return false;
  try {
    const opaqueEventPart = createEconomicsOpaqueEventPart(
      input.idempotencyKey.trim(),
    );
    await recordMoneyLedgerRow({
      eventParts: [input.operation, opaqueEventPart, input.metric],
      subjectKey: economicsSubjectKey(input.subject),
      metric: input.metric,
      amountMicroUsd: input.amountMicroUsd,
      occurredAt: input.occurredAt ?? new Date(),
      resource: input.resource,
      dimensions: input.dimensions,
    });
    return true;
  } catch (error) {
    logMeteringFailure(input.operation, error);
    return false;
  }
}

type OpenAiUsageLike = {
  prompt_tokens?: number | null;
  input_tokens?: number | null;
  completion_tokens?: number | null;
  output_tokens?: number | null;
  prompt_tokens_details?: { cached_tokens?: number | null } | null;
  input_tokens_details?: { cached_tokens?: number | null } | null;
  completion_tokens_details?: { reasoning_tokens?: number | null } | null;
  output_tokens_details?: { reasoning_tokens?: number | null } | null;
};

export interface OpenAiTokenClasses {
  input: number;
  output: number;
  cached: number;
  reasoning: number;
  actual: boolean;
}

export function exactUtf8Bytes(value: string): number {
  return Buffer.byteLength(value, "utf8");
}

export function vendorRequestId(
  response: unknown,
  fallback?: string | null,
): string | undefined {
  if (response && typeof response === "object" && "_request_id" in response) {
    const value = (response as { _request_id?: unknown })._request_id;
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return fallback?.trim() || undefined;
}

export function transcriptionDurationMilliseconds(
  vendorSeconds: unknown,
  fallbackSeconds: unknown,
): { quantity: number; basis: MeasurementBasis } | null {
  const valid = (value: unknown): value is number =>
    typeof value === "number" && Number.isFinite(value) && value >= 0;
  if (valid(vendorSeconds)) {
    return { quantity: Math.round(vendorSeconds * 1_000), basis: "exact" };
  }
  if (valid(fallbackSeconds)) {
    return { quantity: Math.round(fallbackSeconds * 1_000), basis: "estimated" };
  }
  return null;
}

export function economicsOpenAiModel(model: string): {
  resource: UnitEconomicsResource;
  dimension: NonNullable<UnitEconomicsDimensions["model"]>;
} {
  const normalized = model.trim().toLowerCase();
  if (normalized === "gpt-4o-mini") {
    return { resource: "openai.gpt-4o-mini", dimension: "gpt-4o-mini" };
  }
  if (normalized === "gpt-5") {
    return { resource: "openai.gpt-5", dimension: "gpt-5" };
  }
  if (normalized === "gpt-5.5") {
    return { resource: "openai.gpt-5.5", dimension: "gpt-5.5" };
  }
  if (normalized === "gpt-5.5-pro") {
    return { resource: "openai.gpt-5.5-pro", dimension: "gpt-5.5-pro" };
  }
  throw new Error("Unsupported metered OpenAI model.");
}

function nonnegativeInteger(value: unknown): number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0
    ? value
    : 0;
}

export function extractOpenAiTokenClasses(
  usage: OpenAiUsageLike | null | undefined,
  estimate?: { input: number; output: number },
): OpenAiTokenClasses {
  if (usage) {
    const totalInput = nonnegativeInteger(usage.input_tokens ?? usage.prompt_tokens);
    const totalOutput = nonnegativeInteger(usage.output_tokens ?? usage.completion_tokens);
    const cached = Math.min(
      totalInput,
      nonnegativeInteger(
        usage.input_tokens_details?.cached_tokens ??
          usage.prompt_tokens_details?.cached_tokens,
      ),
    );
    const reasoning = Math.min(
      totalOutput,
      nonnegativeInteger(
        usage.output_tokens_details?.reasoning_tokens ??
          usage.completion_tokens_details?.reasoning_tokens,
      ),
    );
    return {
      input: totalInput - cached,
      output: totalOutput - reasoning,
      cached,
      reasoning,
      actual: true,
    };
  }
  return {
    input: nonnegativeInteger(estimate?.input),
    output: nonnegativeInteger(estimate?.output),
    cached: 0,
    reasoning: 0,
    actual: false,
  };
}

export async function meterOpenAiChatUsage(input: {
  operation: string;
  subject: RawEconomicsSubject | ApiGuardContext;
  idempotencyKey?: string;
  resource: UnitEconomicsResource;
  modelDimension: NonNullable<UnitEconomicsDimensions["model"]>;
  usage: OpenAiUsageLike | null | undefined;
  estimate?: { input: number; output: number };
}): Promise<void> {
  const tokens = extractOpenAiTokenClasses(input.usage, input.estimate);
  await commitOpenAiChatReservation(input.subject, tokens);
  const measurementBasis: MeasurementBasis = tokens.actual ? "exact" : "estimated";
  const dimensions: UnitEconomicsDimensions = {
    provider: "openai",
    model: input.modelDimension,
  };
  const rows: Array<[BillableMetric, number]> = [
    ["ai_input_tokens", tokens.input],
    ["ai_output_tokens", tokens.output],
    ["ai_cached_tokens", tokens.cached],
    ["ai_reasoning_tokens", tokens.reasoning],
  ];
  await Promise.all(rows
    .filter(([, quantity]) => quantity > 0)
    .map(([metric, quantity]) => meterBestEffort({
      operation: input.operation,
      subject: input.subject,
      idempotencyKey: input.idempotencyKey,
      metric,
      resource: input.resource,
      quantity,
      dimensions,
      measurementBasis,
    })));
}

export async function meterConfiguredOpenAiChatUsage(input: {
  operation: string;
  subject: RawEconomicsSubject | ApiGuardContext;
  idempotencyKey?: string;
  model: string;
  usage: OpenAiUsageLike | null | undefined;
}): Promise<void> {
  let model: ReturnType<typeof economicsOpenAiModel>;
  try {
    model = economicsOpenAiModel(input.model);
  } catch {
    await commitOpenAiChatReservation(
      input.subject,
      extractOpenAiTokenClasses(input.usage),
    );
    console.error(JSON.stringify({
      operation: input.operation,
      errorCode: "MODEL_NOT_ALLOWLISTED",
    }));
    return;
  }
  await meterOpenAiChatUsage({
    operation: input.operation,
    subject: input.subject,
    idempotencyKey: input.idempotencyKey,
    resource: model.resource,
    modelDimension: model.dimension,
    usage: input.usage,
  });
}
