import { createHash, randomUUID } from "node:crypto";

import { NextResponse } from "next/server";

import {
  listServerJournalEntries,
  upsertServerJournalEntries,
} from "@/lib/server/journal-store";
import { getServerSession } from "@/lib/server/session";
import type { JournalEntry } from "@/types/journal";
import {
  serializeJsonBody,
  serializedJsonResponse,
} from "@/lib/server/serialized-json-response";
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

  const rows = await listServerJournalEntries(session.userId);
  const payload = {
    entries: rows.map((r) => ({
      ...r.payload,
      _syncStatus: r.syncStatus,
      _serverUpdatedAt: r.updatedAt,
    })),
  };
  const serialized = serializeJsonBody(payload);
  const operationNonce = randomUUID();
  await Promise.all([
    meterBestEffort({
      operation: "journal.list.egress",
      subject: { kind: "user", id: session.userId },
      idempotencyKey: operationNonce,
      metric: "egress_bytes",
      resource: "network.egress",
      quantity: serialized.bytes,
      measurementBasis: "exact",
    }),
    meterBestEffort({
      operation: "journal.list.retrieval",
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

export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  let body: { entries?: JournalEntry[] };
  let rawBody: string;
  try {
    rawBody = await request.text();
    body = JSON.parse(rawBody) as { entries?: JournalEntry[] };
  } catch {
    return NextResponse.json({ error: "Invalid body." }, { status: 400 });
  }

  const entries = body.entries ?? [];
  if (!Array.isArray(entries) || entries.length > 200) {
    return NextResponse.json(
      { error: "At most 200 entries per sync.", code: "BATCH_TOO_LARGE" },
      { status: 400 },
    );
  }

  const result = await upsertServerJournalEntries(
    session.userId,
    entries.map((entry) => ({ entry, syncStatus: "synced" })),
  );

  const payload = { ok: true, upserted: result.upserted };
  const serialized = serializeJsonBody(payload);
  const idempotencyKey =
    request.headers.get("x-vm-idempotency-key")?.trim() ||
    createHash("sha256").update(rawBody).digest("base64url");
  await Promise.all([
    meterBestEffort({
      operation: "journal.upsert.ingress",
      subject: { kind: "user", id: session.userId },
      idempotencyKey,
      metric: "ingress_bytes",
      resource: "network.ingress",
      quantity: Buffer.byteLength(rawBody, "utf8"),
      measurementBasis: "exact",
    }),
    meterBestEffort({
      operation: "journal.upsert.egress",
      subject: { kind: "user", id: session.userId },
      idempotencyKey,
      metric: "egress_bytes",
      resource: "network.egress",
      quantity: serialized.bytes,
      measurementBasis: "exact",
    }),
  ]);
  return serializedJsonResponse(serialized);
}
