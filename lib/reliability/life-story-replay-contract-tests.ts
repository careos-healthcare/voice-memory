import assert from "node:assert/strict";

import {
  GET,
  MAX_LIFE_STORY_REPLAY_BODY_BYTES,
} from "@/experiments/backend/app/api/life-story-replay/route";
import {
  LIFE_STORY_REPLAY_PRIVACY_HEADERS,
  parseLifeStoryReplayOutput,
  parseLifeStoryReplayRequest,
} from "@/backend/src/ai/life-story-replay/contracts";
import { LifeStoryReplayOutputSchema } from "@/backend/src/ai/life-story-replay/schema";
import { buildFallbackLifeStoryReplay } from "@/backend/src/ai/life-story-replay/service";

const requestValue = {
  version: "life-story-replay-v1",
  milestones: [
    {
      id: "m-01",
      timestampMs: 1_700_000_000_000,
      kind: "identityShift",
      significance: 0.94,
      sentiment: 0.2,
      nodeIds: ["n-01"],
      clusterIds: ["c-01"],
      projected: false,
    },
  ],
  chapters: [
    {
      id: "ch-01",
      ordinal: 0,
      startMs: 1_700_000_000_000,
      endMs: 1_700_000_000_000,
      milestoneIds: ["m-01"],
    },
  ],
} as const;

export async function runLifeStoryReplayContractTests(): Promise<void> {
  const parsed = parseLifeStoryReplayRequest(requestValue);
  assert.equal(parsed.milestones[0]?.kind, "identityShift");
  assert.throws(
    () =>
      parseLifeStoryReplayRequest({
        ...requestValue,
        transcript: "private journal content",
      }),
    /fields are invalid/,
  );
  assert.throws(
    () =>
      parseLifeStoryReplayRequest({
        ...requestValue,
        chapters: [{ ...requestValue.chapters[0], milestoneIds: ["unknown"] }],
      }),
    /unknown milestone/,
  );

  const fallback = buildFallbackLifeStoryReplay(parsed);
  const output = parseLifeStoryReplayOutput(fallback, parsed);
  assert.equal(output.chapters.length, 1);
  assert.deepEqual(output.chapters[0]?.cues[0]?.nodeIds, ["n-01"]);
  assert.equal(LifeStoryReplayOutputSchema.additionalProperties, false);

  const response = await GET();
  assert.equal(response.status, 405);
  assert.equal(
    response.headers.get("x-ai-data-retention"),
    LIFE_STORY_REPLAY_PRIVACY_HEADERS["X-AI-Data-Retention"],
  );
  assert.equal(response.headers.get("x-openai-store"), "false");
  assert.match(response.headers.get("cache-control") ?? "", /no-store/);
  const discovery = await response.json();
  assert.equal(discovery.maxBodyBytes, MAX_LIFE_STORY_REPLAY_BODY_BYTES);
}

