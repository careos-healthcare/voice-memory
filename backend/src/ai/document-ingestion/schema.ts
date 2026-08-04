import {
  MAX_DOCUMENT_INGESTION_CONCEPTS,
  MAX_DOCUMENT_INGESTION_RELATIONSHIPS,
} from "@/lib/document-ingestion/document-ingestion-contract";

const citationChunkIdsSchema = {
  type: "array",
  minItems: 1,
  maxItems: 4,
  uniqueItems: true,
  items: {
    type: "string",
    minLength: 1,
    maxLength: 128,
    pattern: "^[A-Za-z0-9_-]+$",
  },
} as const;

export const DocumentIngestionOutputSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    concepts: {
      type: "array",
      minItems: 1,
      maxItems: MAX_DOCUMENT_INGESTION_CONCEPTS,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          id: { type: "string", pattern: "^[A-Za-z0-9_-]{1,128}$" },
          label: { type: "string", minLength: 1, maxLength: 120 },
          kind: { type: "string", pattern: "^[A-Za-z0-9_-]{1,64}$" },
          summary: { type: "string", minLength: 1, maxLength: 480 },
          citationChunkIds: citationChunkIdsSchema,
        },
        required: ["id", "label", "kind", "summary", "citationChunkIds"],
      },
    },
    entities: {
      type: "array",
      minItems: 0,
      maxItems: 12,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          id: { type: "string", pattern: "^[A-Za-z0-9_-]{1,128}$" },
          label: { type: "string", minLength: 1, maxLength: 120 },
          type: { type: "string", pattern: "^[A-Za-z0-9_-]{1,64}$" },
          citationChunkIds: citationChunkIdsSchema,
        },
        required: ["id", "label", "type", "citationChunkIds"],
      },
    },
    arguments: {
      type: "array",
      minItems: 0,
      maxItems: 8,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          id: { type: "string", pattern: "^[A-Za-z0-9_-]{1,128}$" },
          claim: { type: "string", minLength: 1, maxLength: 480 },
          stance: { type: "string", pattern: "^[A-Za-z0-9_-]{1,64}$" },
          citationChunkIds: citationChunkIdsSchema,
        },
        required: ["id", "claim", "stance", "citationChunkIds"],
      },
    },
    categoryTags: {
      type: "array",
      minItems: 0,
      maxItems: 8,
      uniqueItems: true,
      items: { type: "string", minLength: 1, maxLength: 80 },
    },
    relationships: {
      type: "array",
      minItems: 0,
      maxItems: MAX_DOCUMENT_INGESTION_RELATIONSHIPS,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          sourceConceptId: {
            type: "string",
            pattern: "^[A-Za-z0-9_-]{1,128}$",
          },
          targetConceptId: {
            type: "string",
            pattern: "^[A-Za-z0-9_-]{1,128}$",
          },
          type: { type: "string", pattern: "^[A-Za-z0-9_-]{1,64}$" },
          citationChunkIds: citationChunkIdsSchema,
        },
        required: [
          "sourceConceptId",
          "targetConceptId",
          "type",
          "citationChunkIds",
        ],
      },
    },
  },
  required: [
    "concepts",
    "entities",
    "arguments",
    "categoryTags",
    "relationships",
  ],
} as const;
