import "server-only";

import { randomUUID } from "node:crypto";

import { dbQuery } from "@/lib/server/db";
import type {
  ConsentStatus,
  RelationshipType,
  UpsertUserRelationshipInput,
  UserRelationshipRecord,
} from "@/types/user-relationship";

function rowToRecord(row: Record<string, unknown>): UserRelationshipRecord {
  const agreedScopeRaw = row.agreed_scope;
  const agreedScope =
    agreedScopeRaw &&
    typeof agreedScopeRaw === "object" &&
    !Array.isArray(agreedScopeRaw)
      ? (agreedScopeRaw as Record<string, unknown>)
      : {};

  return {
    id: String(row.id),
    clientId: String(row.client_id),
    professionalId: String(row.professional_id),
    relationshipType: String(row.relationship_type) as RelationshipType,
    consentStatus: String(row.consent_status) as ConsentStatus,
    agreedScope,
    activeConsentTokenId:
      row.active_consent_token_id == null
        ? undefined
        : String(row.active_consent_token_id),
    createdAt: new Date(String(row.created_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at)).toISOString(),
  };
}

export async function upsertUserRelationship(
  input: UpsertUserRelationshipInput,
): Promise<UserRelationshipRecord> {
  const id = input.id?.trim() || randomUUID();
  const now = new Date().toISOString();
  const relationshipType = input.relationshipType ?? "professional";

  const result = await dbQuery<Record<string, unknown>>(
    `INSERT INTO user_relationships (
       id, client_id, professional_id, relationship_type,
       consent_status, agreed_scope, active_consent_token_id,
       created_at, updated_at
     ) VALUES (
       $1, $2, $3, $4, $5, $6::jsonb, $7, $8::timestamptz, $8::timestamptz
     )
     ON CONFLICT (id) DO UPDATE SET
       consent_status = EXCLUDED.consent_status,
       agreed_scope = EXCLUDED.agreed_scope,
       active_consent_token_id = EXCLUDED.active_consent_token_id,
       updated_at = EXCLUDED.updated_at
     RETURNING *`,
    [
      id,
      input.clientId,
      input.professionalId,
      relationshipType,
      input.consentStatus,
      JSON.stringify(input.agreedScope ?? {}),
      input.activeConsentTokenId ?? null,
      now,
    ],
  );

  return rowToRecord(result.rows[0]!);
}

export async function listRelationshipsForUser(
  userId: string,
): Promise<UserRelationshipRecord[]> {
  const result = await dbQuery<Record<string, unknown>>(
    `SELECT * FROM user_relationships
     WHERE client_id = $1 OR professional_id = $1
     ORDER BY updated_at DESC`,
    [userId],
  );
  return result.rows.map(rowToRecord);
}

export async function getRelationshipById(
  id: string,
): Promise<UserRelationshipRecord | null> {
  const result = await dbQuery<Record<string, unknown>>(
    `SELECT * FROM user_relationships WHERE id = $1 LIMIT 1`,
    [id],
  );
  if (result.rowCount === 0) return null;
  return rowToRecord(result.rows[0]!);
}

export async function updateRelationshipConsentStatus(
  id: string,
  consentStatus: ConsentStatus,
  userId: string,
): Promise<UserRelationshipRecord | null> {
  const result = await dbQuery<Record<string, unknown>>(
    `UPDATE user_relationships
     SET consent_status = $1, updated_at = now()
     WHERE id = $2 AND (client_id = $3 OR professional_id = $3)
     RETURNING *`,
    [consentStatus, id, userId],
  );
  if (result.rowCount === 0) return null;
  return rowToRecord(result.rows[0]!);
}
