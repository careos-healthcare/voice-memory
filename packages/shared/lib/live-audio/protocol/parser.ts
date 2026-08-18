import type { LiveServerEvent } from "@/lib/live-audio/protocol/types";

function asRecord(value: unknown): Record<string, unknown> | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function readInlineAudio(part: Record<string, unknown>): LiveServerEvent | null {
  const inlineData = asRecord(part.inlineData);
  if (!inlineData) return null;
  const data = inlineData.data;
  if (typeof data !== "string" || data.length === 0) return null;
  const mimeType =
    typeof inlineData.mimeType === "string" ? inlineData.mimeType : undefined;
  return { type: "audio_output", pcmBase64: data, mimeType };
}

function readTranscription(
  value: unknown,
  type: "input_transcription" | "output_transcription",
): LiveServerEvent | null {
  const record = asRecord(value);
  if (!record) return null;
  const text = record.text;
  if (typeof text !== "string" || text.trim().length === 0) return null;
  return type === "input_transcription"
    ? { type: "input_transcription", text }
    : { type: "output_transcription", text };
}

/** Parses one Bidi server JSON frame into domain events. */
export function parseLiveServerMessage(raw: unknown): LiveServerEvent[] {
  const message = asRecord(raw);
  if (!message) return [];

  const events: LiveServerEvent[] = [];

  if ("setupComplete" in message) {
    events.push({ type: "setup_complete" });
  }

  if ("goAway" in message) {
    const goAway = asRecord(message.goAway);
    events.push({
      type: "go_away",
      timeLeft: typeof goAway?.timeLeft === "string" ? goAway.timeLeft : undefined,
    });
  }

  const serverContent = asRecord(message.serverContent);
  if (serverContent) {
    if (serverContent.interrupted === true) {
      events.push({ type: "interrupted" });
    }
    if (serverContent.turnComplete === true) {
      events.push({ type: "turn_complete" });
    }

    const inputTranscription = readTranscription(
      serverContent.inputTranscription,
      "input_transcription",
    );
    if (inputTranscription) events.push(inputTranscription);

    const outputTranscription = readTranscription(
      serverContent.outputTranscription,
      "output_transcription",
    );
    if (outputTranscription) events.push(outputTranscription);

    const modelTurn = asRecord(serverContent.modelTurn);
    const parts = modelTurn?.parts;
    if (Array.isArray(parts)) {
      for (const part of parts) {
        const partRecord = asRecord(part);
        if (!partRecord) continue;
        const audio = readInlineAudio(partRecord);
        if (audio) events.push(audio);
      }
    }
  }

  const error = asRecord(message.error);
  if (error) {
    const messageText =
      typeof error.message === "string"
        ? error.message
        : typeof error.status === "string"
          ? error.status
          : "live_server_error";
    events.push({ type: "error", message: messageText });
  }

  if (events.length === 0) {
    events.push({ type: "unknown", keys: Object.keys(message) });
  }

  return events;
}

export function parseLiveServerJson(rawJson: string): LiveServerEvent[] {
  try {
    return parseLiveServerMessage(JSON.parse(rawJson));
  } catch {
    return [{ type: "error", message: "invalid_server_json" }];
  }
}

/** Validates client JSON before forwarding to Gemini upstream. */
export function parseLiveClientMessage(raw: unknown):
  | { ok: true; message: Record<string, unknown> }
  | { ok: false; reason: string } {
  const message = asRecord(raw);
  if (!message) return { ok: false, reason: "invalid_client_json" };

  const keys = Object.keys(message);
  if (keys.length !== 1) {
    return { ok: false, reason: "client_message_must_have_exactly_one_top_level_key" };
  }

  const allowed = new Set(["setup", "clientContent", "realtimeInput", "toolResponse"]);
  if (!allowed.has(keys[0] ?? "")) {
    return { ok: false, reason: "unsupported_client_message_key" };
  }

  if ("realtimeInput" in message) {
    const realtimeInput = asRecord(message.realtimeInput);
    if (!realtimeInput) return { ok: false, reason: "invalid_realtime_input" };

    if ("mediaChunks" in realtimeInput) {
      return { ok: false, reason: "deprecated_media_chunks" };
    }

    if ("audio" in realtimeInput) {
      const audio = asRecord(realtimeInput.audio);
      if (!audio || typeof audio.data !== "string" || typeof audio.mimeType !== "string") {
        return { ok: false, reason: "invalid_audio_blob" };
      }
    }
  }

  return { ok: true, message };
}

export function serializeLiveClientMessage(message: Record<string, unknown>): string {
  return JSON.stringify(message);
}
