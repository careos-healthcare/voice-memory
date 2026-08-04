export const SEARCH_NODE_TYPES = [
  "person",
  "emotion",
  "goal",
] as const;

export type SearchNodeType = (typeof SEARCH_NODE_TYPES)[number];

export interface SearchTimeframe {
  start: string;
  end: string;
}

export interface SearchIntent {
  semantic_query: string;
  timeframe: SearchTimeframe | null;
  node_types: SearchNodeType[];
  required_entities: string[];
}

export const SearchIntentSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    semantic_query: {
      type: "string",
      minLength: 1,
      maxLength: 500,
    },
    timeframe: {
      anyOf: [
        {
          type: "object",
          additionalProperties: false,
          properties: {
            start: {
              type: "string",
              description: "Inclusive ISO 8601 UTC boundary.",
            },
            end: {
              type: "string",
              description: "Exclusive ISO 8601 UTC boundary.",
            },
          },
          required: ["start", "end"],
        },
        { type: "null" },
      ],
    },
    node_types: {
      type: "array",
      maxItems: SEARCH_NODE_TYPES.length,
      items: { type: "string", enum: SEARCH_NODE_TYPES },
    },
    required_entities: {
      type: "array",
      maxItems: 12,
      items: { type: "string", minLength: 1, maxLength: 100 },
    },
  },
  required: [
    "semantic_query",
    "timeframe",
    "node_types",
    "required_entities",
  ],
} as const;

export function parseSearchTranslatorRequest(value: unknown): string {
  if (!value || typeof value !== "object") {
    throw new Error("Search translator body must be an object.");
  }
  const object = value as Record<string, unknown>;
  if (
    Object.keys(object).some((key) => key !== "query") ||
    typeof object.query !== "string" ||
    object.query.trim().length === 0 ||
    object.query.length > 500
  ) {
    throw new Error("query must be a non-empty string of at most 500 characters.");
  }
  return object.query.trim();
}

export function parseSearchIntent(value: unknown): SearchIntent {
  if (!value || typeof value !== "object") {
    throw new Error("Invalid structured search intent.");
  }
  const object = value as Record<string, unknown>;
  const allowed = new Set([
    "semantic_query",
    "timeframe",
    "node_types",
    "required_entities",
  ]);
  if (Object.keys(object).some((key) => !allowed.has(key))) {
    throw new Error("Structured search intent contains unknown fields.");
  }
  const semanticQuery = object.semantic_query;
  const timeframe = parseTimeframe(object.timeframe);
  const nodeTypes = object.node_types;
  const entities = object.required_entities;
  if (
    typeof semanticQuery !== "string" ||
    semanticQuery.trim().length === 0 ||
    semanticQuery.length > 500 ||
    !Array.isArray(nodeTypes) ||
    !Array.isArray(entities)
  ) {
    throw new Error("Structured search intent has an invalid shape.");
  }
  const parsedNodeTypes = [...new Set(nodeTypes)].map(String);
  if (
    parsedNodeTypes.length > SEARCH_NODE_TYPES.length ||
    parsedNodeTypes.some(
      (type) => !SEARCH_NODE_TYPES.includes(type as SearchNodeType),
    )
  ) {
    throw new Error("Structured search intent contains invalid node types.");
  }
  const parsedEntities = [...new Set(entities.map(String).map((item) => item.trim()))]
    .filter(Boolean)
    .slice(0, 12);
  return {
    semantic_query: semanticQuery.trim(),
    timeframe,
    node_types: parsedNodeTypes as SearchNodeType[],
    required_entities: parsedEntities,
  };
}

export function normalizeSearchIntentTimeframe(
  intent: SearchIntent,
  rawQuery: string,
  now: Date = new Date(),
): SearchIntent {
  return {
    ...intent,
    timeframe: resolveSearchTimeframe(rawQuery, now) ?? intent.timeframe,
  };
}

function parseTimeframe(value: unknown): SearchTimeframe | null {
  if (value === null) return null;
  if (!value || typeof value !== "object") {
    throw new Error("Structured search intent has an invalid timeframe.");
  }
  const object = value as Record<string, unknown>;
  if (
    Object.keys(object).some((key) => key !== "start" && key !== "end") ||
    typeof object.start !== "string" ||
    typeof object.end !== "string"
  ) {
    throw new Error("Structured search intent has an invalid timeframe.");
  }
  const start = new Date(object.start);
  const end = new Date(object.end);
  if (
    !Number.isFinite(start.getTime()) ||
    !Number.isFinite(end.getTime()) ||
    start >= end
  ) {
    throw new Error("Structured search timeframe boundaries are invalid.");
  }
  return utcRange(start, end);
}

export function resolveSearchTimeframe(
  phrase: string | null,
  now: Date = new Date(),
): SearchTimeframe | null {
  if (!phrase) return null;
  const normalized = phrase.trim().toLowerCase();
  const midnight = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
  if (normalized === "all time") return null;

  if (normalized.includes("last summer")) {
    const currentYear = now.getUTCFullYear();
    const summerYear = currentYear - (now.getUTCMonth() >= 5 ? 1 : 2);
    return utcRange(
      new Date(Date.UTC(summerYear, 5, 1)),
      new Date(Date.UTC(summerYear, 8, 1)),
    );
  }

  if (
    normalized.includes("two weeks ago") ||
    normalized.includes("past two weeks") ||
    normalized.includes("last two weeks")
  ) {
    return utcRange(
      new Date(midnight.getTime() - 14 * 86_400_000),
      midnight,
    );
  }

  const days = /(?:last|past)\s+(\d+)\s+days?/.exec(normalized);
  if (days) {
    const count = Math.max(1, Math.min(3650, Number(days[1])));
    return utcRange(
      new Date(midnight.getTime() - count * 86_400_000),
      midnight,
    );
  }

  if (normalized.includes("this month")) {
    return utcRange(
      new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)),
      new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)),
    );
  }

  if (normalized.includes("this year")) {
    return utcRange(
      new Date(Date.UTC(now.getUTCFullYear(), 0, 1)),
      new Date(Date.UTC(now.getUTCFullYear() + 1, 0, 1)),
    );
  }

  return null;
}

function utcRange(start: Date, end: Date): SearchTimeframe {
  return {
    start: start.toISOString(),
    end: end.toISOString(),
  };
}
