import type { EntryPhotoMeta } from "@/types/personalization";
import type { EntryAtmosphereMeta } from "@/types/atmosphere";
import type { TranscriptCleanupMeta } from "@/types/transcript-cleanup";
import type { ImageEvidence } from "@/types/image-evidence";

export interface Reflection {
  mood: string;
  emotionalIntensity: number;
  recurringThemes: string[];
  /** Legacy — kept for search/export compatibility; de-emphasized in UI. */
  hiddenConcern: string;
  /** Legacy — kept for search/export compatibility; de-emphasized in UI. */
  positiveSignal: string;
  /** Legacy — kept for search/export compatibility; de-emphasized in UI. */
  recommendation: string;
  /** Short quote or paraphrase of exact wording from the transcript. */
  exactLanguagePattern?: string;
  /** Concrete, transcript-grounded observation (no vague therapy phrasing). */
  concreteObservation?: string;
  /** Pattern that showed up more than once in this entry. */
  repeatedSignal?: string;
  /** Tension or contradiction within this entry's language. */
  tensionOrContradiction?: string;
  /** Topic circled without direct naming — vague or indirect phrasing. */
  avoidedOrVagueArea?: string;
  /** Legacy action field — de-emphasized in UI. */
  nextSmallAction?: string;
  /** Observation-style statements: "You repeatedly…", "You tend to…" */
  patternObservations?: string[];
}

export interface JournalEntry {
  id: string;
  createdAt: string;
  transcript: string;
  /** Original ASR transcript before quiet cleanup, when preserved. */
  rawTranscript?: string;
  /** Cleanup metadata for preserved phrase anchors. */
  transcriptCleanup?: TranscriptCleanupMeta;
  reflection: Reflection;
  durationSeconds: number;
  /** Set when original recording is stored in IndexedDB. */
  audioId?: string;
  /** Saved in listening mode — reflection generated later on request. */
  reflectionPending?: boolean;
  /** Optional quiet photo attachment — stored locally in IndexedDB. */
  photo?: EntryPhotoMeta;
  /** Optional image evidence — caption citeable in fact_ledger; blob local-only. */
  imageEvidence?: ImageEvidence;
  /** How this entry was captured — voice, text, import, or image_caption. */
  captureSource?: "voice" | "text" | "import" | "image_caption";
  /** Optional abstract atmosphere — user-initiated, stored locally. */
  atmosphere?: EntryAtmosphereMeta;
  /**
   * Sync-versioning metadata — mirrors the mobile `JournalEntry` model
   * (apps/mobile/lib/models/journal_entry.dart). Optional here
   * so legacy/pre-migration clients that don't send these yet are never
   * rejected; the server treats a missing value as schema v1 and defaults
   * it the same way mobile's migration does (updatedAt=createdAt, revision=1).
   */
  /** Mutable, UTC. Updated on every meaningful edit — the primary sync-conflict input alongside `revision`. */
  updatedAt?: string;
  /** Positive, monotonically-increasing per-entry edit counter. Starts at 1. */
  revision?: number;
  /** Deterministic conflict tie-breaker string; lexically-greater wins when revision+updatedAt tie. */
  changeId?: string;
  /** Tombstone marker — non-null means this entry was deleted and the deletion must propagate to other devices. */
  deletedAt?: string;
  /** Schema version this entry was constructed/migrated against. */
  schemaVersion?: number;
}

export type ProcessingStage = "transcribing" | "analyzing" | "saving";
