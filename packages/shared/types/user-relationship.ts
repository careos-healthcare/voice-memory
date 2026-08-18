/**
 * Unified client ↔ professional/caregiver relationship contracts.
 */

export type RelationshipType = "professional" | "caregiver";

export type ConsentStatus = "pending" | "active" | "revoked";

export interface UserRelationshipRecord {
  id: string;
  clientId: string;
  professionalId: string;
  relationshipType: RelationshipType;
  consentStatus: ConsentStatus;
  /** JSON permissions / feature flags agreed by the client. */
  agreedScope: Record<string, unknown>;
  activeConsentTokenId?: string;
  /** ISO-8601 UTC */
  createdAt: string;
  /** ISO-8601 UTC */
  updatedAt: string;
}

export interface UpsertUserRelationshipInput {
  id?: string;
  clientId: string;
  professionalId: string;
  relationshipType?: RelationshipType;
  consentStatus: ConsentStatus;
  agreedScope?: Record<string, unknown>;
  activeConsentTokenId?: string;
}
