import "server-only";

import { NextResponse } from "next/server";

import {
  ANALYZE_UNAVAILABLE_MESSAGE,
  analyzeRouteClientError as buildAnalyzeRouteClientError,
  classifyAnalyzeRouteError as classifyAnalyzeFailure,
  type AnalyzeRouteFailureCode,
} from "@/lib/analyze/analyze-route-failure";

export type { AnalyzeRouteFailureCode } from "@/lib/analyze/analyze-route-failure";
export { ANALYZE_UNAVAILABLE_MESSAGE } from "@/lib/analyze/analyze-route-failure";

const LOG_PREFIX = "ARCHIVEME_ANALYZE";

export function logAnalyzeStep(message: string): void {
  console.info(`${LOG_PREFIX}_STEP ${message}`);
}

export function logAnalyzeFailure(code: string, reason: string): void {
  console.error(`${LOG_PREFIX}_FAILED code=${code} reason=${reason}`);
}

export function logAnalyzeFailureType(code: string, error: unknown): void {
  const type =
    error instanceof Error
      ? error.name || "Error"
      : typeof error === "object" && error !== null
        ? error.constructor?.name ?? "object"
        : typeof error;
  const status =
    typeof error === "object" &&
    error !== null &&
    "status" in error &&
    typeof (error as { status?: unknown }).status === "number"
      ? (error as { status: number }).status
      : null;
  const statusSuffix = status == null ? "" : ` httpStatus=${status}`;
  logAnalyzeFailure(code, `failureType=${type}${statusSuffix}`);
}

export function analyzeRouteErrorResponse(
  code: AnalyzeRouteFailureCode,
  message: string,
  status: number,
  extra?: Record<string, unknown>,
): NextResponse {
  logAnalyzeFailure(code, message);
  return NextResponse.json({ error: message, code, ...extra }, { status });
}

export function classifyAnalyzeRouteError(error: unknown): {
  code: AnalyzeRouteFailureCode;
  message: string;
  status: number;
} {
  return classifyAnalyzeFailure(error);
}

export function analyzeRouteClientError(error: unknown): {
  code: AnalyzeRouteFailureCode;
  message: string;
  status: number;
} {
  const client = buildAnalyzeRouteClientError(error);
  logAnalyzeFailureType(client.code, error);
  return client;
}

export function analyzeRouteCatchResponse(error: unknown): NextResponse {
  const client = analyzeRouteClientError(error);
  return NextResponse.json(
    { error: client.message, code: client.code },
    { status: client.status },
  );
}
