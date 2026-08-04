import {
  MORNING_BRIEFING_MAX_SECONDS,
  MORNING_BRIEFING_MIN_SECONDS,
  MORNING_BRIEFING_SECTION_TITLES,
} from "./contracts";

const opaqueIdArraySchema = {
  type: "array",
  maxItems: 16,
  uniqueItems: true,
  items: {
    type: "string",
    minLength: 1,
    maxLength: 64,
    pattern: "^[A-Za-z0-9_-]+$",
  },
} as const;

const sectionSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: { type: "string", enum: MORNING_BRIEFING_SECTION_TITLES },
    ttsText: { type: "string", minLength: 1, maxLength: 2_000 },
    highlightedNodeIds: opaqueIdArraySchema,
    highlightedClusterIds: opaqueIdArraySchema,
  },
  required: [
    "title",
    "ttsText",
    "highlightedNodeIds",
    "highlightedClusterIds",
  ],
} as const;

export const MorningBriefingOutputSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    version: { type: "string", const: "morning-briefing-v1" },
    estimatedDurationSeconds: {
      type: "integer",
      minimum: MORNING_BRIEFING_MIN_SECONDS,
      maximum: MORNING_BRIEFING_MAX_SECONDS,
    },
    sections: {
      type: "array",
      minItems: 3,
      maxItems: 3,
      items: sectionSchema,
    },
  },
  required: ["version", "estimatedDurationSeconds", "sections"],
} as const;
