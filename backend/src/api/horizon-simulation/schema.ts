const unit = { type: "number", minimum: 0, maximum: 1 } as const;

export const HorizonSimulationResultSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    projections: {
      type: "array",
      minItems: 3,
      maxItems: 3,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          id: {
            type: "string",
            pattern: "^[a-z0-9][a-z0-9_-]{0,63}$",
          },
          year: { type: "integer", enum: [1, 3, 5] },
          label: { type: "string", minLength: 1, maxLength: 240 },
          nodeType: {
            type: "string",
            enum: [
              "decision",
              "goal",
              "project",
              "emotion",
              "outcome",
              "habit",
            ],
          },
          probability: unit,
          vectors: {
            type: "object",
            additionalProperties: false,
            properties: {
              financial: unit,
              emotional: unit,
              career: unit,
              cognitiveLoad: unit,
              alignment: unit,
              reward: unit,
            },
            required: [
              "financial",
              "emotional",
              "career",
              "cognitiveLoad",
              "alignment",
              "reward",
            ],
          },
          rippleEffects: {
            type: "array",
            maxItems: 8,
            items: { type: "string", minLength: 1, maxLength: 160 },
          },
        },
        required: [
          "id",
          "year",
          "label",
          "nodeType",
          "probability",
          "vectors",
          "rippleEffects",
        ],
      },
    },
  },
  required: ["projections"],
} as const;
