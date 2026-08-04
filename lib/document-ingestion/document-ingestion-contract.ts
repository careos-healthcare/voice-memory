export const MAX_DOCUMENT_INGESTION_CHUNKS = 12;
export const MAX_DOCUMENT_INGESTION_CHUNK_CHARS = 3_000;
export const MAX_DOCUMENT_INGESTION_TOTAL_CHARS = 24_000;
export const MAX_DOCUMENT_INGESTION_CONCEPTS = 12;
export const MAX_DOCUMENT_INGESTION_RELATIONSHIPS = 16;

export const DOCUMENT_INGESTION_PRIVACY_HEADERS = {
  "Cache-Control": "private, no-store, no-cache, must-revalidate, max-age=0",
  Pragma: "no-cache",
  Expires: "0",
  "X-Content-Type-Options": "nosniff",
  "X-AI-Data-Retention": "none",
  "X-OpenAI-Store": "false",
} as const;

const OPAQUE_ID = /^[A-Za-z0-9_-]{1,128}$/;
const FORBIDDEN_FIELD_PARTS = [
  "url",
  "uri",
  "path",
  "file",
  "blob",
  "binary",
  "base64",
  "audio",
  "video",
  "image",
  "media",
  "graph",
  "node",
  "edge",
  "journal",
  "entry",
  "transcript",
  "recording",
  "userid",
  "email",
  "name",
] as const;

export interface DocumentIngestionChunk {
  id: string;
  text: string;
}

export interface DocumentIngestionRequest {
  documentId: string;
  format: string;
  chunks: DocumentIngestionChunk[];
}

export interface DocumentIngestionConcept {
  id: string;
  label: string;
  kind: string;
  summary: string;
  citationChunkIds: string[];
}

export interface DocumentIngestionEntity {
  id: string;
  label: string;
  type: string;
  citationChunkIds: string[];
}

export interface DocumentIngestionArgument {
  id: string;
  claim: string;
  stance: string;
  citationChunkIds: string[];
}

export interface DocumentIngestionRelationship {
  sourceConceptId: string;
  targetConceptId: string;
  type: string;
  citationChunkIds: string[];
}

export interface DocumentIngestionResult {
  concepts: DocumentIngestionConcept[];
  entities: DocumentIngestionEntity[];
  arguments: DocumentIngestionArgument[];
  categoryTags: string[];
  relationships: DocumentIngestionRelationship[];
}

export function parseDocumentIngestionRequest(
  value: unknown,
): DocumentIngestionRequest {
  rejectForbiddenFields(value);
  const object = strictRecord(
    value,
    ["documentId", "format", "chunks"],
    "Document ingestion request",
  );
  const chunks = boundedArray(
    object.chunks,
    1,
    MAX_DOCUMENT_INGESTION_CHUNKS,
    "chunks",
  ).map((value, index) => {
    const chunk = strictRecord(value, ["id", "text"], `chunks[${index}]`);
    return {
      id: opaqueId(chunk.id, `chunks[${index}].id`),
      text: boundedText(
        chunk.text,
        MAX_DOCUMENT_INGESTION_CHUNK_CHARS,
        `chunks[${index}].text`,
      ),
    };
  });
  ensureUnique(
    chunks.map((chunk) => chunk.id),
    "Chunk IDs",
  );
  const totalChars = chunks.reduce(
    (total, chunk) => total + chunk.text.length,
    0,
  );
  if (totalChars > MAX_DOCUMENT_INGESTION_TOTAL_CHARS) {
    throw new Error(
      `Selected chunk text must not exceed ${MAX_DOCUMENT_INGESTION_TOTAL_CHARS} characters.`,
    );
  }
  return {
    documentId: opaqueId(object.documentId, "documentId"),
    format: boundedToken(object.format, "format"),
    chunks,
  };
}

export function parseDocumentIngestionResult(
  value: unknown,
  request: DocumentIngestionRequest,
): DocumentIngestionResult {
  const object = strictRecord(
    value,
    ["concepts", "entities", "arguments", "categoryTags", "relationships"],
    "Document ingestion result",
  );
  const allowedChunkIds = new Set(request.chunks.map((chunk) => chunk.id));
  const concepts = boundedArray(
    object.concepts,
    1,
    MAX_DOCUMENT_INGESTION_CONCEPTS,
    "concepts",
  ).map((value, index) => {
    const item = strictRecord(
      value,
      ["id", "label", "kind", "summary", "citationChunkIds"],
      `concepts[${index}]`,
    );
    return {
      id: opaqueId(item.id, `concepts[${index}].id`),
      label: boundedText(item.label, 120, `concepts[${index}].label`),
      kind: boundedToken(item.kind, `concepts[${index}].kind`),
      summary: boundedText(item.summary, 480, `concepts[${index}].summary`),
      citationChunkIds: citations(
        item.citationChunkIds,
        allowedChunkIds,
        `concepts[${index}]`,
      ),
    };
  });
  ensureUnique(
    concepts.map((item) => item.id),
    "Concept IDs",
  );
  const conceptIds = new Set(concepts.map((item) => item.id));
  const entities = boundedArray(object.entities, 0, 12, "entities").map(
    (value, index) => {
      const item = strictRecord(
        value,
        ["id", "label", "type", "citationChunkIds"],
        `entities[${index}]`,
      );
      return {
        id: opaqueId(item.id, `entities[${index}].id`),
        label: boundedText(item.label, 120, `entities[${index}].label`),
        type: boundedToken(item.type, `entities[${index}].type`),
        citationChunkIds: citations(
          item.citationChunkIds,
          allowedChunkIds,
          `entities[${index}]`,
        ),
      };
    },
  );
  ensureUnique(
    entities.map((item) => item.id),
    "Entity IDs",
  );
  const argumentsResult = boundedArray(object.arguments, 0, 8, "arguments").map(
    (value, index) => {
      const item = strictRecord(
        value,
        ["id", "claim", "stance", "citationChunkIds"],
        `arguments[${index}]`,
      );
      return {
        id: opaqueId(item.id, `arguments[${index}].id`),
        claim: boundedText(item.claim, 480, `arguments[${index}].claim`),
        stance: boundedToken(item.stance, `arguments[${index}].stance`),
        citationChunkIds: citations(
          item.citationChunkIds,
          allowedChunkIds,
          `arguments[${index}]`,
        ),
      };
    },
  );
  ensureUnique(
    argumentsResult.map((item) => item.id),
    "Argument IDs",
  );
  const categoryTags = boundedArray(
    object.categoryTags,
    0,
    8,
    "categoryTags",
  ).map((tag, index) => boundedText(tag, 80, `categoryTags[${index}]`));
  ensureUnique(categoryTags, "Category tags");
  const relationships = boundedArray(
    object.relationships,
    0,
    MAX_DOCUMENT_INGESTION_RELATIONSHIPS,
    "relationships",
  ).map((value, index) => {
    const item = strictRecord(
      value,
      ["sourceConceptId", "targetConceptId", "type", "citationChunkIds"],
      `relationships[${index}]`,
    );
    const sourceConceptId = opaqueId(
      item.sourceConceptId,
      `relationships[${index}].sourceConceptId`,
    );
    const targetConceptId = opaqueId(
      item.targetConceptId,
      `relationships[${index}].targetConceptId`,
    );
    if (!conceptIds.has(sourceConceptId) || !conceptIds.has(targetConceptId)) {
      throw new Error(`relationships[${index}] references an unknown concept.`);
    }
    return {
      sourceConceptId,
      targetConceptId,
      type: boundedToken(item.type, `relationships[${index}].type`),
      citationChunkIds: citations(
        item.citationChunkIds,
        allowedChunkIds,
        `relationships[${index}]`,
      ),
    };
  });
  return {
    concepts,
    entities,
    arguments: argumentsResult,
    categoryTags,
    relationships,
  };
}

function citations(
  value: unknown,
  allowedChunkIds: ReadonlySet<string>,
  label: string,
): string[] {
  const result = boundedArray(value, 1, 4, `${label}.citationChunkIds`).map(
    (item, index) => opaqueId(item, `${label}.citationChunkIds[${index}]`),
  );
  ensureUnique(result, `${label}.citationChunkIds`);
  if (result.some((id) => !allowedChunkIds.has(id))) {
    throw new Error(
      `${label}.citationChunkIds contains a chunk ID not present in chunks.`,
    );
  }
  return result;
}

function rejectForbiddenFields(value: unknown): void {
  if (Array.isArray(value)) {
    value.forEach(rejectForbiddenFields);
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
    const normalized = key.replace(/[^a-z0-9]/gi, "").toLowerCase();
    if (
      key !== "chunkId" &&
      FORBIDDEN_FIELD_PARTS.some((part) => normalized.includes(part))
    ) {
      throw new Error(`Forbidden document-ingestion field: ${key}.`);
    }
    rejectForbiddenFields(child);
  }
}

function strictRecord(
  value: unknown,
  allowedKeys: readonly string[],
  label: string,
): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  const object = value as Record<string, unknown>;
  if (Object.keys(object).some((key) => !allowedKeys.includes(key))) {
    throw new Error(`${label} contains unknown fields.`);
  }
  if (allowedKeys.some((key) => !(key in object))) {
    throw new Error(`${label} is missing required fields.`);
  }
  return object;
}

function boundedArray(
  value: unknown,
  min: number,
  max: number,
  label: string,
): unknown[] {
  if (!Array.isArray(value) || value.length < min || value.length > max) {
    throw new Error(`${label} must contain between ${min} and ${max} items.`);
  }
  return value;
}

function opaqueId(value: unknown, label: string): string {
  if (typeof value !== "string" || !OPAQUE_ID.test(value)) {
    throw new Error(`${label} must be a request-scoped opaque identifier.`);
  }
  return value;
}

function boundedText(value: unknown, max: number, label: string): string {
  if (
    typeof value !== "string" ||
    value.trim().length === 0 ||
    value.length > max ||
    /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/u.test(value)
  ) {
    throw new Error(`${label} is invalid.`);
  }
  return value.trim();
}

function boundedToken(value: unknown, label: string): string {
  const token = boundedText(value, 64, label);
  if (!/^[A-Za-z0-9_-]+$/.test(token)) {
    throw new Error(`${label} must be a bounded token.`);
  }
  return token;
}

function ensureUnique(values: readonly string[], label: string): void {
  if (new Set(values).size !== values.length) {
    throw new Error(`${label} must be unique.`);
  }
}
