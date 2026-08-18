import "server-only";

import { randomUUID } from "node:crypto";

import { getOpenAIClient } from "@/lib/openai";
import {
  guardOpenAiRoute,
  MAX_AUDIO_BYTES,
  MAX_TRANSCRIPT_CHARS,
} from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { generateEvidenceBackedInsight } from "@/src/services/insights/generator";
import type { BulkIngestChunkInput } from "@/src/services/ledger/bulk_ingest";
import {
  bulkIngestHistoricalChunks,
  normalizeBulkIngestChunk,
  pickLatestImportedChunkText,
} from "@/src/services/ledger/bulk_ingest";

import type { ArchiveInsightKind, PatternMatchConfidenceBand } from "@/types/insights";
import { normalizeLifeStageLens } from "@/types/user-context";

export const MAX_BULK_IMPORT_BATCH_SIZE = 25;

export interface BulkImportChunkPayload {
  entryId?: string;
  rawText?: string;
  createdAt?: string;
  sourceFile?: string;
}

export interface BulkImportJsonRequestBody {
  chunks?: BulkImportChunkPayload[];
  /** When true, generate a Day-1 cold-start insight after this batch commits. */
  finalizeColdStart?: boolean;
  /** Optional transcript anchor for retrieval; defaults to newest chunk in this batch. */
  coldStartTranscript?: string;
  /** Optional thematic lens for cold-start insight generation. */
  activeLens?: string;
}

export interface BulkImportInsightResponse {
  id: string;
  insightText: string;
  kind: ArchiveInsightKind;
  confidenceBand: PatternMatchConfidenceBand;
  citedEntryIds: string[];
}

export interface BulkImportJsonSuccessResponse {
  ok: true;
  imported: number;
  failed: number;
  errors: string[];
  insight?: BulkImportInsightResponse;
}

export type BulkImportJsonResult =
  | BulkImportJsonSuccessResponse
  | BulkImportRouteError;

function normalizeChunks(body: BulkImportJsonRequestBody): {
  chunks: BulkIngestChunkInput[];
  invalidCount: number;
} {
  const rawChunks = Array.isArray(body.chunks) ? body.chunks : [];
  const chunks: BulkIngestChunkInput[] = [];
  let invalidCount = 0;
  for (const chunk of rawChunks) {
    const normalized = normalizeBulkIngestChunk(chunk);
    if (normalized == null) {
      invalidCount += 1;
    } else {
      chunks.push(normalized);
    }
  }
  return { chunks, invalidCount };
}

async function maybeGenerateColdStartInsight(
  userId: string,
  importedRawTexts: readonly { rawText: string; createdAt: string }[],
  coldStartTranscript: string | undefined,
  activeLens?: string,
): Promise<BulkImportInsightResponse | undefined> {
  if (!process.env.OPENAI_API_KEY?.trim()) {
    return undefined;
  }

  const latestFromBatch = pickLatestImportedChunkText(
    importedRawTexts.map((row) => ({
      id: "",
      userId,
      entryId: "",
      rawText: row.rawText,
      createdAt: row.createdAt,
    })),
  );
  const transcript = (coldStartTranscript?.trim() || latestFromBatch).trim();
  if (!transcript) return undefined;

  const insight = await generateEvidenceBackedInsight(userId, transcript, {
    isColdStartPass: true,
    activeLens: normalizeLifeStageLens(activeLens),
  });

  return {
    id: randomUUID(),
    insightText: insight.insightText,
    kind: insight.kind,
    confidenceBand: insight.confidenceBand,
    citedEntryIds: insight.citedEntryIds,
  };
}

export async function postBulkImportJson(
  userId: string,
  body: BulkImportJsonRequestBody,
): Promise<BulkImportJsonResult> {
  const { chunks, invalidCount } = normalizeChunks(body);

  if (chunks.length === 0) {
    return {
      ok: false,
      error: "chunks must contain at least one valid entryId and rawText pair.",
      code: "CHUNKS_REQUIRED",
      status: 400,
    };
  }
  if (chunks.length > MAX_BULK_IMPORT_BATCH_SIZE) {
    return {
      ok: false,
      error: `At most ${MAX_BULK_IMPORT_BATCH_SIZE} chunks per request.`,
      code: "BATCH_TOO_LARGE",
      status: 400,
    };
  }

  const tooLong = chunks.find((chunk) => chunk.rawText.length > MAX_TRANSCRIPT_CHARS);
  if (tooLong) {
    return {
      ok: false,
      error: `rawText exceeds ${MAX_TRANSCRIPT_CHARS} characters for entry ${tooLong.entryId}.`,
      code: "TRANSCRIPT_TOO_LONG",
      status: 413,
    };
  }

  const ingestResult = await bulkIngestHistoricalChunks(userId, chunks);
  const errors = [
    ...Array.from({ length: invalidCount }, () => "Invalid chunk: entryId and rawText are required."),
    ...ingestResult.failed.map((failure) => `${failure.entryId}: ${failure.error}`),
  ];

  let insight: BulkImportInsightResponse | undefined;
  if (body.finalizeColdStart === true && ingestResult.imported.length > 0) {
    try {
      insight = await maybeGenerateColdStartInsight(
        userId,
        ingestResult.imported,
        body.coldStartTranscript,
        body.activeLens,
      );
    } catch (error) {
      console.error("bulk-import cold-start insight failed", error);
      errors.push(
        error instanceof Error ? error.message : "Cold-start insight generation failed.",
      );
    }
  }

  return {
    ok: true,
    imported: ingestResult.imported.length,
    failed: ingestResult.failed.length + invalidCount,
    errors,
    ...(insight ? { insight } : {}),
  };
}

export interface BulkImportRouteError {
  ok: false;
  error: string;
  code: string;
  status: number;
}

export interface BulkImportAudioSuccessResponse {
  ok: true;
  imported: number;
  failed: number;
  entryId: string;
  sourceFile: string;
  insight?: BulkImportInsightResponse;
}

export type BulkImportAudioResult =
  | BulkImportAudioSuccessResponse
  | BulkImportRouteError;

export async function postBulkImportAudio(
  userId: string,
  formData: FormData,
  request: Request,
): Promise<BulkImportAudioResult> {
  const audio = formData.get("audio");
  const entryIdRaw = formData.get("entryId");
  const sourceFileRaw = formData.get("sourceFile");
  const createdAtRaw = formData.get("createdAt");
  const finalizeColdStartRaw = formData.get("finalizeColdStart");
  const coldStartTranscriptRaw = formData.get("coldStartTranscript");
  const activeLensRaw = formData.get("activeLens");

  const entryId = typeof entryIdRaw === "string" ? entryIdRaw.trim() : "";
  const sourceFile =
    typeof sourceFileRaw === "string" && sourceFileRaw.trim()
      ? sourceFileRaw.trim()
      : "audio";
  const finalizeColdStart =
    typeof finalizeColdStartRaw === "string" &&
    finalizeColdStartRaw.trim().toLowerCase() === "true";
  const coldStartTranscript =
    typeof coldStartTranscriptRaw === "string" ? coldStartTranscriptRaw : undefined;
  const activeLens =
    typeof activeLensRaw === "string" && activeLensRaw.trim()
      ? activeLensRaw.trim()
      : undefined;

  if (!(audio instanceof File) || audio.size === 0) {
    return {
      ok: false,
      error: "audio file is required.",
      code: "AUDIO_REQUIRED",
      status: 400,
    };
  }
  if (!entryId) {
    return {
      ok: false,
      error: "entryId is required.",
      code: "ENTRY_ID_REQUIRED",
      status: 400,
    };
  }
  if (audio.size > MAX_AUDIO_BYTES) {
    return {
      ok: false,
      error: `Audio must be under ${Math.round(MAX_AUDIO_BYTES / (1024 * 1024))}MB.`,
      code: "PAYLOAD_TOO_LARGE",
      status: 413,
    };
  }

  if (!process.env.OPENAI_API_KEY?.trim()) {
    return {
      ok: false,
      error: "Transcription is not configured.",
      code: "OPENAI_NOT_CONFIGURED",
      status: 503,
    };
  }

  const guard = await guardOpenAiRoute(request, "transcribe", {
    audioBytes: audio.size,
  });
  if (!guard.ok) {
    const payload = await guard.response.json().catch(() => ({}));
    return {
      ok: false,
      error:
        typeof payload === "object" &&
        payload != null &&
        "error" in payload &&
        typeof payload.error === "string"
          ? payload.error
          : "Transcription request blocked.",
      code:
        typeof payload === "object" &&
        payload != null &&
        "code" in payload &&
        typeof payload.code === "string"
          ? payload.code
          : "TRANSCRIBE_BLOCKED",
      status: guard.response.status,
    };
  }

  let transcript: string;
  try {
    const openai = getOpenAIClient();
    const transcription = await openai.audio.transcriptions.create({
      file: audio,
      model: "whisper-1",
      language: "en",
    });
    transcript = transcription.text?.trim() ?? "";
  } catch (error) {
    console.error("bulk-import audio transcription failed", error);
    const safe = safeOpenAiRouteError("transcribe", error);
    return {
      ok: false,
      error: safe.message,
      code: safe.code,
      status: 500,
    };
  }

  if (!transcript) {
    return {
      ok: false,
      error: "Could not detect speech in the audio file.",
      code: "NO_SPEECH",
      status: 422,
    };
  }
  if (transcript.length > MAX_TRANSCRIPT_CHARS) {
    return {
      ok: false,
      error: `Transcript exceeds ${MAX_TRANSCRIPT_CHARS} characters.`,
      code: "TRANSCRIPT_TOO_LONG",
      status: 413,
    };
  }

  const normalizedChunk = normalizeBulkIngestChunk({
    entryId,
    rawText: transcript,
    createdAt: typeof createdAtRaw === "string" ? createdAtRaw : undefined,
  });
  if (!normalizedChunk) {
    return {
      ok: false,
      error: "Transcribed audio chunk is invalid.",
      code: "INVALID_CHUNK",
      status: 400,
    };
  }

  const ingestResult = await bulkIngestHistoricalChunks(userId, [normalizedChunk]);
  if (ingestResult.imported.length === 0) {
    const failure = ingestResult.failed[0];
    return {
      ok: false,
      error: failure?.error ?? "Audio chunk import failed.",
      code: "BULK_IMPORT_FAILED",
      status: 500,
    };
  }

  let insight: BulkImportInsightResponse | undefined;
  if (finalizeColdStart) {
    try {
      insight = await maybeGenerateColdStartInsight(
        userId,
        ingestResult.imported,
        coldStartTranscript ?? transcript,
        activeLens,
      );
    } catch (error) {
      console.error("bulk-import audio cold-start insight failed", error);
    }
  }

  return {
    ok: true,
    imported: 1,
    failed: 0,
    entryId,
    sourceFile,
    ...(insight ? { insight } : {}),
  };
}
