import { randomUUID } from "node:crypto";

import { NextResponse } from "next/server";

import { exportServerJournal } from "@/lib/server/journal-store";
import {
  serializeJsonBody,
  serializedJsonResponse,
} from "@/lib/server/serialized-json-response";
import { getServerSession } from "@/lib/server/session";
import { meterBestEffort } from "@/lib/server/unit-economics-meter";

export const runtime = "nodejs";

export async function GET() {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  const entries = await exportServerJournal(session.userId);
  const payload = {
    exportedAt: new Date().toISOString(),
    count: entries.length,
    entries,
  };
  const serialized = serializeJsonBody(payload);
  const operationNonce = randomUUID();
  await Promise.all([
    meterBestEffort({
      operation: "journal.export.egress",
      subject: { kind: "user", id: session.userId },
      idempotencyKey: operationNonce,
      metric: "egress_bytes",
      resource: "network.egress",
      quantity: serialized.bytes,
      measurementBasis: "exact",
    }),
    meterBestEffort({
      operation: "journal.export.retrieval",
      subject: { kind: "user", id: session.userId },
      idempotencyKey: operationNonce,
      metric: "retrieval_bytes",
      resource: "network.retrieval",
      quantity: serialized.bytes,
      measurementBasis: "exact",
    }),
  ]);
  return serializedJsonResponse(serialized);
}
