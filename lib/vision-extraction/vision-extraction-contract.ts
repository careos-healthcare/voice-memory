export const VISION_ENTITY_KINDS = [
  "person",
  "place",
  "object",
  "text",
] as const;

export type VisionEntityKind = (typeof VISION_ENTITY_KINDS)[number];

export interface VisionEntity {
  kind: VisionEntityKind;
  label: string;
  confidence: number;
}

export interface VisionRelationship {
  source: string;
  target: string;
  relationship: string;
  confidence: number;
}

export interface VisionExtraction {
  sceneSummary: string;
  visibleText: string[];
  entities: VisionEntity[];
  relationships: VisionRelationship[];
}

const CONFIDENCE_SCHEMA = {
  type: "number",
  minimum: 0,
  maximum: 1,
} as const;

export const VisionExtractionSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    sceneSummary: {
      type: "string",
      minLength: 1,
      maxLength: 1_000,
    },
    visibleText: {
      type: "array",
      maxItems: 100,
      items: { type: "string", minLength: 1, maxLength: 500 },
    },
    entities: {
      type: "array",
      maxItems: 100,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          kind: { type: "string", enum: VISION_ENTITY_KINDS },
          label: { type: "string", minLength: 1, maxLength: 160 },
          confidence: CONFIDENCE_SCHEMA,
        },
        required: ["kind", "label", "confidence"],
      },
    },
    relationships: {
      type: "array",
      maxItems: 100,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          source: { type: "string", minLength: 1, maxLength: 160 },
          target: { type: "string", minLength: 1, maxLength: 160 },
          relationship: { type: "string", minLength: 1, maxLength: 160 },
          confidence: CONFIDENCE_SCHEMA,
        },
        required: ["source", "target", "relationship", "confidence"],
      },
    },
  },
  required: ["sceneSummary", "visibleText", "entities", "relationships"],
} as const;

export function parseVisionExtraction(value: unknown): VisionExtraction {
  const object = strictRecord(
    value,
    ["sceneSummary", "visibleText", "entities", "relationships"],
    "Vision extraction",
  );
  const sceneSummary = boundedString(object.sceneSummary, 1_000, "sceneSummary");

  if (!Array.isArray(object.visibleText) || object.visibleText.length > 100) {
    throw new Error("visibleText must be an array with at most 100 items.");
  }
  const visibleText = object.visibleText.map((item) =>
    boundedString(item, 500, "visibleText item"),
  );

  if (!Array.isArray(object.entities) || object.entities.length > 100) {
    throw new Error("entities must be an array with at most 100 items.");
  }
  const entities = object.entities.map((item): VisionEntity => {
    const entity = strictRecord(
      item,
      ["kind", "label", "confidence"],
      "Vision entity",
    );
    if (
      typeof entity.kind !== "string" ||
      !VISION_ENTITY_KINDS.includes(entity.kind as VisionEntityKind)
    ) {
      throw new Error("Vision entity kind is invalid.");
    }
    return {
      kind: entity.kind as VisionEntityKind,
      label: boundedString(entity.label, 160, "Vision entity label"),
      confidence: confidence(entity.confidence),
    };
  });

  if (
    !Array.isArray(object.relationships) ||
    object.relationships.length > 100
  ) {
    throw new Error("relationships must be an array with at most 100 items.");
  }
  const entityLabels = new Set(entities.map((entity) => entity.label));
  const relationships = object.relationships.map(
    (item): VisionRelationship => {
      const edge = strictRecord(
        item,
        ["source", "target", "relationship", "confidence"],
        "Vision relationship",
      );
      const source = boundedString(edge.source, 160, "Relationship source");
      const target = boundedString(edge.target, 160, "Relationship target");
      if (!entityLabels.has(source) || !entityLabels.has(target)) {
        throw new Error("Relationship endpoints must reference entity labels.");
      }
      return {
        source,
        target,
        relationship: boundedString(
          edge.relationship,
          160,
          "Relationship label",
        ),
        confidence: confidence(edge.confidence),
      };
    },
  );

  return { sceneSummary, visibleText, entities, relationships };
}

function strictRecord(
  value: unknown,
  allowedKeys: readonly string[],
  label: string,
): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
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

function boundedString(value: unknown, max: number, label: string): string {
  if (
    typeof value !== "string" ||
    value.trim().length === 0 ||
    value.length > max ||
    /[\u0000-\u0008\u000B\u000C\u000E-\u001F]/.test(value)
  ) {
    throw new Error(`${label} is invalid.`);
  }
  return value.trim();
}

function confidence(value: unknown): number {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < 0 ||
    value > 1
  ) {
    throw new Error("Confidence must be a number between 0 and 1.");
  }
  return value;
}
