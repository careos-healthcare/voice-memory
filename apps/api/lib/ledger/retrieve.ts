import "server-only";

import {
  retrieveEvidence,
  type EvidenceMatch,
} from "@/src/services/ledger/retrieve";

export type { EvidenceMatch };
export { retrieveEvidence };

/** @deprecated Use `EvidenceMatch`. */
export type FactLedgerMatch = EvidenceMatch;

/** @deprecated Use `retrieveEvidence`. */
export interface RetrieveFactLedgerOptions {
  limit?: number;
}

/** @deprecated Use `retrieveEvidence`. */
export async function retrieveFactLedgerMatches(
  userId: string,
  query: string,
  options: RetrieveFactLedgerOptions = {},
): Promise<FactLedgerMatch[]> {
  return retrieveEvidence(userId, query, options.limit ?? 5);
}
