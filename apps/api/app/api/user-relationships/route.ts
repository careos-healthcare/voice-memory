import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import {
  listRelationshipsForUser,
  upsertUserRelationship,
} from "@/lib/server/user-relationships-store";
import { getServerSession } from "@/lib/server/session";
import type {
  ConsentStatus,
  RelationshipType,
} from "@/types/user-relationship";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function parseConsentStatus(raw: unknown): ConsentStatus | null {
  if (raw === "pending" || raw === "active" || raw === "revoked") return raw;
  return null;
}

function parseRelationshipType(raw: unknown): RelationshipType | null {
  if (raw === "professional" || raw === "caregiver") return raw;
  return null;
}

/** List relationships where the signed-in user is client or professional. */
export async function GET() {
  const session = await getServerSession();
  if (!session?.userId) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "user-relationships",
    });
  }

  try {
    const relationships = await listRelationshipsForUser(session.userId);
    return NextResponse.json({ ok: true, relationships });
  } catch (error) {
    console.error("GET /api/user-relationships failed", error);
    return apiErrorFromException(error, {
      code: "RELATIONSHIPS_LIST_FAILED",
      route: "user-relationships",
      logEvent: "api_error",
    });
  }
}

/** Create or update a relationship the caller participates in. */
export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session?.userId) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "user-relationships",
    });
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return apiErrorResponse({
      code: "INVALID_BODY",
      route: "user-relationships",
      internalCategory: "validation",
    });
  }

  const clientId =
    typeof body.clientId === "string" ? body.clientId.trim() : "";
  const professionalId =
    typeof body.professionalId === "string" ? body.professionalId.trim() : "";
  const consentStatus = parseConsentStatus(body.consentStatus);
  const relationshipType = parseRelationshipType(body.relationshipType);
  const id = typeof body.id === "string" ? body.id.trim() : undefined;
  const activeConsentTokenId =
    typeof body.activeConsentTokenId === "string"
      ? body.activeConsentTokenId.trim()
      : undefined;
  const agreedScope =
    body.agreedScope && typeof body.agreedScope === "object" && !Array.isArray(body.agreedScope)
      ? (body.agreedScope as Record<string, unknown>)
      : {};

  if (!clientId || !professionalId) {
    return apiErrorResponse({ code: "INVALID_PARTIES", route: "user-relationships" });
  }

  if (!consentStatus) {
    return apiErrorResponse({ code: "INVALID_CONSENT_STATUS", route: "user-relationships" });
  }

  if (session.userId !== clientId && session.userId !== professionalId) {
    return apiErrorResponse({
      code: "FORBIDDEN",
      route: "user-relationships",
      internalCategory: "forbidden",
    });
  }

  try {
    const relationship = await upsertUserRelationship({
      id,
      clientId,
      professionalId,
      relationshipType: relationshipType ?? undefined,
      consentStatus,
      agreedScope,
      activeConsentTokenId,
    });
    return NextResponse.json({ ok: true, relationship });
  } catch (error) {
    console.error("POST /api/user-relationships failed", error);
    return apiErrorFromException(error, {
      code: "RELATIONSHIPS_UPSERT_FAILED",
      route: "user-relationships",
      logEvent: "api_error",
    });
  }
}
