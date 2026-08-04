import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import { DocumentIngestionOutputSchema } from "@/backend/src/ai/document-ingestion/schema";
import {
  GET,
  MAX_DOCUMENT_INGESTION_BODY_BYTES,
  POST,
} from "@/experiments/backend/app/api/document-ingestion/route";
import {
  DOCUMENT_INGESTION_PRIVACY_HEADERS,
  MAX_DOCUMENT_INGESTION_CHUNKS,
  parseDocumentIngestionRequest,
  parseDocumentIngestionResult,
} from "@/lib/document-ingestion/document-ingestion-contract";

const validRequest = {
  documentId: "doc_A1B2C3D4",
  format: "pdf",
  chunks: [
    {
      id: "chunk_A1",
      text: "The selected report says the pilot started in May and involved two teams.",
    },
    {
      id: "chunk_B2",
      text: "The report describes lower response time, while noting that the sample was small.",
    },
  ],
} as const;

export async function runDocumentIngestionContractTests(): Promise<void> {
  const request = parseDocumentIngestionRequest(validRequest);
  assert.equal(request.chunks.length, 2);
  assert.equal(MAX_DOCUMENT_INGESTION_CHUNKS, 12);

  const result = parseDocumentIngestionResult(
    {
      concepts: [
        {
          id: "concept_pilot",
          label: "Pilot",
          kind: "project",
          summary: "A pilot involving two teams.",
          citationChunkIds: ["chunk_A1"],
        },
        {
          id: "concept_latency",
          label: "Response time",
          kind: "finding",
          summary: "Response time improved in a small sample.",
          citationChunkIds: ["chunk_B2"],
        },
      ],
      entities: [],
      arguments: [],
      categoryTags: ["operations"],
      relationships: [
        {
          sourceConceptId: "concept_pilot",
          targetConceptId: "concept_latency",
          type: "reported",
          citationChunkIds: ["chunk_A1", "chunk_B2"],
        },
      ],
    },
    request,
  );
  assert.equal(result.concepts.length, 2);
  assert.equal(DocumentIngestionOutputSchema.additionalProperties, false);
  assert.equal(
    DocumentIngestionOutputSchema.properties.concepts.items
      .additionalProperties,
    false,
  );

  assert.throws(
    () =>
      parseDocumentIngestionResult(
        {
          concepts: [
            {
              id: "concept_invalid",
              label: "Unsupported",
              kind: "claim",
              summary: "Unsupported point.",
              citationChunkIds: ["chunk_not_selected"],
            },
          ],
          entities: [],
          arguments: [],
          categoryTags: [],
          relationships: [],
        },
        request,
      ),
    /not present in chunks/,
  );

  assert.throws(
    () =>
      parseDocumentIngestionRequest({
        ...validRequest,
        chunks: [validRequest.chunks[0], validRequest.chunks[0]],
      }),
    /must be unique/,
  );

  for (const forbidden of [
    { url: "https://example.invalid/document" },
    { filePath: "/private/document.pdf" },
    { rawFile: "bytes" },
    { media: "attachment" },
    { personalGraph: { nodes: [] } },
    { journalEntries: [] },
    { transcript: "private speech" },
  ]) {
    assert.throws(
      () => parseDocumentIngestionRequest({ ...validRequest, ...forbidden }),
      /Forbidden document-ingestion field/,
    );
  }

  assert.throws(
    () =>
      parseDocumentIngestionRequest({
        documentId: validRequest.documentId,
        format: validRequest.format,
        chunks: [
          ...Array.from(
            { length: MAX_DOCUMENT_INGESTION_CHUNKS },
            (_, index) => ({
              id: `chunk_${index}`,
              text: "bounded text",
            }),
          ),
          { id: "chunk_overflow", text: "too many" },
        ],
      }),
    /between 1 and 12/,
  );

  await runRouteRuntimeTests();
  runStaticSafetyTests();
}

async function runRouteRuntimeTests(): Promise<void> {
  const getResponse = await GET();
  assert.equal(getResponse.status, 405);
  assert.equal(getResponse.headers.get("allow"), "POST");
  assertPrivacyHeaders(getResponse);

  const blockedResponse = await POST(
    new Request("https://example.invalid/api/document-ingestion", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: "https://attacker.invalid",
      },
      body: JSON.stringify(validRequest),
    }),
  );
  assert.equal(blockedResponse.status, 403);
  assertPrivacyHeaders(blockedResponse);

  const invalidResponse = await POST(
    new Request("https://example.invalid/api/document-ingestion", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-vm-client": "voicememory-mobile",
      },
      body: JSON.stringify({
        ...validRequest,
        sourceUrl: "https://example.invalid",
      }),
    }),
  );
  assert.equal(invalidResponse.status, 400);
  assert.equal((await invalidResponse.json()).code, "INVALID_REQUEST");
  assertPrivacyHeaders(invalidResponse);

  const oversizedResponse = await POST(
    new Request("https://example.invalid/api/document-ingestion", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "content-length": String(MAX_DOCUMENT_INGESTION_BODY_BYTES + 1),
        "x-vm-client": "voicememory-mobile",
      },
      body: "{}",
    }),
  );
  assert.equal(oversizedResponse.status, 413);
  assertPrivacyHeaders(oversizedResponse);
}

function runStaticSafetyTests(): void {
  const route = fs.readFileSync(
    path.join(process.cwd(), "experiments/backend/app/api/document-ingestion/route.ts"),
    "utf8",
  );
  const service = fs.readFileSync(
    path.join(process.cwd(), "backend/src/ai/document-ingestion/service.ts"),
    "utf8",
  );
  const prompt = fs.readFileSync(
    path.join(process.cwd(), "backend/src/ai/document-ingestion/prompt.ts"),
    "utf8",
  );

  assert.match(route, /export const runtime = "nodejs"/);
  assert.match(route, /export const dynamic = "force-dynamic"/);
  assert.match(route, /32 \* 1024/);
  assert.match(route, /readBoundedBody/);
  assert.match(route, /isAllowedVoiceSessionOrigin/);
  assert.match(route, /guardOpenAiRoute\(request, "analyze"/);
  assert.match(route, /meterConfiguredOpenAiChatUsage/);
  assert.match(service, /type: "json_schema"/);
  assert.match(service, /strict: true/);
  assert.match(service, /store: false/);
  assert.match(prompt, /explicitly selected document chunks/);
  assert.doesNotMatch(route, /\bfetch\s*\(|readFile|createReadStream/);
  assert.doesNotMatch(service, /\bfetch\s*\(|readFile|createReadStream/);
  assert.doesNotMatch(
    `${route}\n${service}`,
    /console\.(?:log|info|debug|warn|error)\([^)]*(?:rawBody|body|content|selectedChunks)/s,
  );
}

function assertPrivacyHeaders(response: Response): void {
  assert.match(response.headers.get("cache-control") ?? "", /no-store/);
  assert.equal(
    response.headers.get("x-ai-data-retention"),
    DOCUMENT_INGESTION_PRIVACY_HEADERS["X-AI-Data-Retention"],
  );
  assert.equal(
    response.headers.get("x-openai-store"),
    DOCUMENT_INGESTION_PRIVACY_HEADERS["X-OpenAI-Store"],
  );
}
