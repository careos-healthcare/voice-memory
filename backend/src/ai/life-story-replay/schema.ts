export const LifeStoryReplayOutputSchema = {
  type: "object",
  additionalProperties: false,
  required: ["version", "title", "chapters"],
  properties: {
    version: { type: "string", const: "life-story-replay-v1" },
    title: { type: "string" },
    chapters: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["id", "title", "narration", "durationMs", "cues"],
        properties: {
          id: { type: "string" },
          title: { type: "string" },
          narration: { type: "string" },
          durationMs: { type: "integer" },
          cues: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: ["offsetMs", "nodeIds", "clusterIds", "emphasis"],
              properties: {
                offsetMs: { type: "integer" },
                nodeIds: { type: "array", items: { type: "string" } },
                clusterIds: { type: "array", items: { type: "string" } },
                emphasis: { type: "number" },
              },
            },
          },
        },
      },
    },
  },
} as const;

