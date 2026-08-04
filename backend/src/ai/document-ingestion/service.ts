import type { ChatCompletion } from "openai/resources/chat/completions";

import {
  parseDocumentIngestionResult,
  type DocumentIngestionRequest,
  type DocumentIngestionResult,
} from "@/lib/document-ingestion/document-ingestion-contract";
import { getOpenAIClient } from "@/lib/openai";

import { DOCUMENT_INGESTION_SYSTEM_PROMPT } from "./prompt";
import { DocumentIngestionOutputSchema } from "./schema";

export interface DocumentIngestionGeneration {
  result: DocumentIngestionResult;
  model: string;
  completion: ChatCompletion;
}

export async function generateDocumentIngestion(
  request: DocumentIngestionRequest,
): Promise<DocumentIngestionGeneration> {
  const model =
    process.env.VOICEMEMORY_DOCUMENT_INGESTION_MODEL?.trim() || "gpt-4o-mini";
  const completion = await getOpenAIClient().chat.completions.create({
    model,
    store: false,
    temperature: 0.1,
    messages: [
      { role: "system", content: DOCUMENT_INGESTION_SYSTEM_PROMPT },
      { role: "user", content: JSON.stringify(request) },
    ],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "document_ingestion",
        strict: true,
        schema: DocumentIngestionOutputSchema,
      },
    },
  });
  const content = completion.choices[0]?.message.content;
  if (!content) throw new Error("DOCUMENT_INGESTION_EMPTY");
  return {
    result: parseDocumentIngestionResult(JSON.parse(content), request),
    model,
    completion,
  };
}
