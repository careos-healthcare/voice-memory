/**
 * Image evidence attached to journal entries — caption text is citeable in
 * the fact ledger; binary payload stays device-local.
 */

export type ImageEvidenceSource = "camera" | "gallery" | "import";

/** Metadata stored on the journal entry and in sync photoMetadata rows. */
export interface ImageEvidence {
  /** Stable id for local blob storage and ledger citation. */
  evidenceId: string;
  /** User caption — indexed into fact_ledger as raw_text when present. */
  caption: string;
  mimeType: string;
  attachedAt: string;
  filename?: string;
  byteLength?: number;
  width?: number;
  height?: number;
  contentHash?: string;
  source?: ImageEvidenceSource;
}

/** Row shape for server-side / sync photo metadata envelopes. */
export interface ImageEvidenceLedgerMeta {
  entryId: string;
  evidenceId: string;
  caption: string;
  mimeType: string;
  attachedAt: string;
  byteLength?: number;
  contentHash?: string;
}
