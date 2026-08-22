import "server-only";

import { getGeminiApiKey } from "@/lib/gemini";

export interface GeminiEmbedContentOptions {
  model: string;
  outputDimensionality?: number;
}

interface GeminiEmbedContentResponse {
  embedding?: {
    values?: number[];
  };
}

function normalizeModelResource(model: string): string {
  const trimmed = model.trim();
  return trimmed.startsWith("models/") ? trimmed.slice("models/".length) : trimmed;
}

/**
 * Generates a text embedding via Gemini `embedContent` (Developer API).
 */
export async function geminiEmbedText(
  text: string,
  options: GeminiEmbedContentOptions,
): Promise<number[]> {
  const input = text.trim();
  if (!input) {
    throw new Error("Cannot embed empty text.");
  }

  const modelId = normalizeModelResource(options.model);
  const body: Record<string, unknown> = {
    model: `models/${modelId}`,
    content: {
      parts: [{ text: input }],
    },
  };

  if (options.outputDimensionality != null) {
    body.outputDimensionality = options.outputDimensionality;
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${modelId}:embedContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": getGeminiApiKey(),
      },
      body: JSON.stringify(body),
    },
  );

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(
      `Gemini embedContent failed (${response.status}): ${errorBody.slice(0, 500)}`,
    );
  }

  const payload = (await response.json()) as GeminiEmbedContentResponse;
  const embedding = payload.embedding?.values;

  if (!embedding?.length) {
    throw new Error("Gemini embedContent returned no embedding vector.");
  }

  return embedding;
}
