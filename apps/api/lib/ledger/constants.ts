/** Gemini embedding model — see `@/types/insights` for vector width. */
export { FACT_LEDGER_EMBEDDING_DIMENSIONS } from "@/types/insights";

export const FACT_LEDGER_EMBEDDING_MODEL =
  process.env.VOICEMEMORY_EMBEDDING_MODEL?.trim() || "text-embedding-004";

export const FACT_LEDGER_RETRIEVAL_LIMIT = 5;
