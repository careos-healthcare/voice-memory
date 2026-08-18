import "server-only";

import { geminiEmbedText } from "@/lib/gemini-embeddings";

import {
  FACT_LEDGER_EMBEDDING_DIMENSIONS,
  FACT_LEDGER_EMBEDDING_MODEL,
} from "./constants";

export function toPgVectorLiteral(values: readonly number[]): string {
  if (values.length !== FACT_LEDGER_EMBEDDING_DIMENSIONS) {
    throw new Error(
      `Expected ${FACT_LEDGER_EMBEDDING_DIMENSIONS} embedding dimensions, got ${values.length}.`,
    );
  }
  return `[${values.join(",")}]`;
}

export async function embedText(text: string): Promise<number[]> {
  const embedding = await geminiEmbedText(text, {
    model: FACT_LEDGER_EMBEDDING_MODEL,
    outputDimensionality: FACT_LEDGER_EMBEDDING_DIMENSIONS,
  });

  if (embedding.length !== FACT_LEDGER_EMBEDDING_DIMENSIONS) {
    throw new Error(
      `Embedding model ${FACT_LEDGER_EMBEDDING_MODEL} returned ${embedding.length} dimensions; expected ${FACT_LEDGER_EMBEDDING_DIMENSIONS}.`,
    );
  }

  return embedding;
}
