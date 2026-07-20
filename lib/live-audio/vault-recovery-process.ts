import { randomUUID } from "node:crypto";
import type { File } from "node:buffer";

import { parseReflectionResponse } from "@/lib/analyze/parse-reflection-response";
import { buildEvidencePacket } from "@/lib/evidence/evidence-pipeline";
import { buildPromptContext, composePromptUserContent } from "@/lib/evidence/prompt-context";
import {
  decryptVaultFile,
  wrapPcm16LeInWav,
} from "@/lib/live-audio/vault-format";
import {
  lookupVaultRecoveryAck,
  lookupVaultRecoverySession,
  recordVaultRecoveryAck,
} from "@/lib/live-audio/vault-recovery-store";
import { getOpenAIClient } from "@/lib/openai";
import type { Reflection } from "@/types/journal";

const ANALYZE_SYSTEM_PROMPT = `You read voice transcripts for ArchiveMe. Return sharp, concrete notes from the speaker's own words — not therapy, not coaching, not diagnosis.

OUTPUT — valid JSON only:
- exactLanguagePattern, concreteObservation, tensionOrContradiction, repeatedSignal, avoidedOrVagueArea, nextSmallAction
- mood, emotionalIntensity, recurringThemes

Quote the speaker directly. Never mention being an AI.`;

export interface VaultRecoveryProcessInput {
  subject: string;
  sessionId: string;
  idempotencyKey: string;
  vaultBytes: Buffer;
  durationSeconds?: number;
  inlineRecoverySecret?: Buffer | null;
}

export interface VaultRecoveryProcessResult {
  recoveryAckId: string;
  duplicate: boolean;
  transcript: string;
  reflection: Reflection;
  durationSeconds: number;
  frameCount: number;
}

const MAX_DURATION_SECONDS = Number(
  process.env.VOICEMEMORY_MAX_RECORDING_SECONDS ?? "120",
);

function resolveVaultRecoverySecret(input: {
  sessionId: string;
  subject: string;
  inlineRecoverySecret?: Buffer | null;
}): Buffer {
  if (input.inlineRecoverySecret) {
    const registered = lookupVaultRecoverySession(input.sessionId, input.subject);
    if (registered.ok && !registered.secret.equals(input.inlineRecoverySecret)) {
      throw new VaultRecoveryProcessError(
        "Provided recovery secret does not match the registered session.",
        "RECOVERY_SECRET_MISMATCH",
        403,
      );
    }
    return input.inlineRecoverySecret;
  }

  const session = lookupVaultRecoverySession(input.sessionId, input.subject);
  if (!session.ok) {
    throw new VaultRecoveryProcessError(
      session.reason === "expired"
        ? "Vault recovery window expired."
        : "Unknown or unauthorized vault session.",
      session.reason === "expired" ? "VAULT_RECOVERY_EXPIRED" : "VAULT_SESSION_UNKNOWN",
      session.reason === "expired" ? 410 : 404,
    );
  }
  return session.secret;
}

function durationSecondsFromVault(decrypted: {
  pcm16Le: Buffer;
  header: { sampleRateHz: number; numChannels: number };
}): number {
  const sampleCount = decrypted.pcm16Le.length / 2 / decrypted.header.numChannels;
  return Math.max(
    1,
    Math.min(MAX_DURATION_SECONDS, Math.ceil(sampleCount / decrypted.header.sampleRateHz)),
  );
}

export async function processVaultRecoveryUpload(
  input: VaultRecoveryProcessInput,
): Promise<VaultRecoveryProcessResult> {
  const existing = lookupVaultRecoveryAck(input.sessionId, input.idempotencyKey);
  if (existing) {
    return {
      recoveryAckId: existing.recoveryAckId,
      duplicate: true,
      transcript: existing.transcript,
      reflection: existing.reflection,
      durationSeconds: existing.durationSeconds,
      frameCount: 0,
    };
  }

  const session = lookupVaultRecoverySession(input.sessionId, input.subject);
  if (!session.ok && !input.inlineRecoverySecret) {
    throw new VaultRecoveryProcessError(
      session.reason === "expired"
        ? "Vault recovery window expired."
        : "Unknown or unauthorized vault session.",
      session.reason === "expired" ? "VAULT_RECOVERY_EXPIRED" : "VAULT_SESSION_UNKNOWN",
      session.reason === "expired" ? 410 : 404,
    );
  }

  const recoverySecret = resolveVaultRecoverySecret({
    sessionId: input.sessionId,
    subject: input.subject,
    inlineRecoverySecret: input.inlineRecoverySecret,
  });
  const decrypted = decryptVaultFile(input.vaultBytes, recoverySecret);
  const durationSeconds =
    input.durationSeconds ?? durationSecondsFromVault(decrypted);
  const wavBytes = wrapPcm16LeInWav(
    decrypted.pcm16Le,
    decrypted.header.sampleRateHz,
    decrypted.header.numChannels,
  );

  const openai = getOpenAIClient();
  const wavFile = new File([wavBytes], "vault-recovery.wav", {
    type: "audio/wav",
  });
  const transcription = await openai.audio.transcriptions.create({
    file: wavFile,
    model: "whisper-1",
    language: "en",
  });
  const transcript = transcription.text?.trim() ?? "";
  if (!transcript) {
    throw new VaultRecoveryProcessError(
      "Could not detect speech in the recovered vault.",
      "NO_SPEECH",
      422,
    );
  }

  const reflection = await analyzeTranscript(transcript);
  const recoveryAckId = randomUUID();
  recordVaultRecoveryAck({
    sessionId: input.sessionId,
    idempotencyKey: input.idempotencyKey,
    recoveryAckId,
    transcript,
    reflection,
    durationSeconds,
  });

  return {
    recoveryAckId,
    duplicate: false,
    transcript,
    reflection,
    durationSeconds,
    frameCount: decrypted.frameCount,
  };
}

async function analyzeTranscript(transcript: string): Promise<Reflection> {
  const { packet } = buildEvidencePacket([], { memoryScope: "automatic" });
  const promptContext = buildPromptContext({
    currentEntry: { transcript },
    evidencePacket: packet,
  });
  const openai = getOpenAIClient();
  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    response_format: { type: "json_object" },
    temperature: 0.35,
    messages: [
      { role: "system", content: ANALYZE_SYSTEM_PROMPT },
      {
        role: "user",
        content: `Read this voice reflection like a sharp mirror. Quote their words. Observations only:\n\n${composePromptUserContent(promptContext)}`,
      },
    ],
  });
  const content = completion.choices[0]?.message?.content;
  if (!content) {
    throw new VaultRecoveryProcessError(
      "No reflection returned from model",
      "MODEL_ERROR",
      502,
    );
  }
  return parseReflectionResponse(content, transcript);
}

export class VaultRecoveryProcessError extends Error {
  constructor(
    message: string,
    readonly code: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "VaultRecoveryProcessError";
  }
}
