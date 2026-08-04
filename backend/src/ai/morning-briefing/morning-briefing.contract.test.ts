import assert from "node:assert/strict";
import { Buffer } from "node:buffer";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

import {
  GET,
  MAX_MORNING_BRIEFING_BODY_BYTES,
  POST,
} from "@/experiments/backend/app/api/morning-briefing/route";

import {
  countWords,
  MAX_RESTING_HEART_RATE_BPM,
  MORNING_BRIEFING_MAX_SECONDS,
  MORNING_BRIEFING_MAX_WORDS,
  MORNING_BRIEFING_MIN_SECONDS,
  MORNING_BRIEFING_MIN_WORDS,
  MORNING_BRIEFING_PRIVACY_HEADERS,
  MORNING_BRIEFING_SECTION_TITLES,
  MIN_RESTING_HEART_RATE_BPM,
  parseMorningBriefing,
  parseMorningBriefingRequest,
} from "./contracts";
import { MorningBriefingOutputSchema } from "./schema";
import {
  buildFallbackMorningBriefing,
  buildMorningBriefingApiResponse,
  combinedMorningBriefingScript,
  synthesizeMorningBriefingAudio,
} from "./service";

const requestValue = {
  restMetrics: {
    windowDays: 7,
    sleepDurationMinutes: 425,
    sleepConsistencyScore: 0.72,
    recoveryScore: 0.64,
    restingHeartRateBpm: 58,
  },
  incompleteMicroHabits: [
    {
      habitId: "habit_01",
      targetNodeId: "node_focus",
      completionRate: 0.43,
      daysIncomplete: 4,
    },
  ],
  semanticClusterVelocityDeltas: [
    {
      clusterId: "cluster_momentum",
      velocityDelta: 0.31,
      activityScore: 0.76,
    },
  ],
  journalTopicSignals: [
    {
      topicId: "topic_steady",
      relatedNodeIds: ["node_topic"],
      salienceScore: 0.81,
      velocityDelta: 0.18,
    },
  ],
} as const;

test("accepts only strict anonymized aggregate input", () => {
  const parsed = parseMorningBriefingRequest(requestValue);
  assert.equal(parsed.restMetrics.windowDays, 7);
  assert.equal(parsed.restMetrics.restingHeartRateBpm, 58);
  assert.equal(parsed.incompleteMicroHabits[0]?.habitId, "habit_01");
  assert.throws(
    () =>
      parseMorningBriefingRequest({
        ...requestValue,
        userId: "raw-user",
      }),
    /Forbidden personal-content field/,
  );
  assert.throws(
    () =>
      parseMorningBriefingRequest({
        ...requestValue,
        restMetrics: { ...requestValue.restMetrics, recoveryScore: 1.1 },
      }),
    /between 0 and 1/,
  );
  assert.equal(
    parseMorningBriefingRequest({
      ...requestValue,
      restMetrics: {
        ...requestValue.restMetrics,
        restingHeartRateBpm: null,
      },
    }).restMetrics.restingHeartRateBpm,
    null,
  );
  assert.throws(
    () =>
      parseMorningBriefingRequest({
        ...requestValue,
        restMetrics: {
          windowDays: requestValue.restMetrics.windowDays,
          sleepDurationMinutes: requestValue.restMetrics.sleepDurationMinutes,
          sleepConsistencyScore:
            requestValue.restMetrics.sleepConsistencyScore,
          recoveryScore: requestValue.restMetrics.recoveryScore,
        },
      }),
    /missing required fields/,
  );
  for (const restingHeartRateBpm of [
    MIN_RESTING_HEART_RATE_BPM - 1,
    MAX_RESTING_HEART_RATE_BPM + 1,
  ]) {
    assert.throws(
      () =>
        parseMorningBriefingRequest({
          ...requestValue,
          restMetrics: {
            ...requestValue.restMetrics,
            restingHeartRateBpm,
          },
        }),
      new RegExp(
        `between ${MIN_RESTING_HEART_RATE_BPM} and ${MAX_RESTING_HEART_RATE_BPM}`,
      ),
    );
  }
  assert.throws(
    () =>
      parseMorningBriefingRequest({
        ...requestValue,
        journalTopicSignals: [
          {
            ...requestValue.journalTopicSignals[0],
            quote: "raw journal material",
          },
        ],
      }),
    /Forbidden personal-content field/,
  );
});

test("structured output schema is strict and exactly three sections", () => {
  assert.equal(MorningBriefingOutputSchema.additionalProperties, false);
  assert.deepEqual(MORNING_BRIEFING_SECTION_TITLES, [
    "Rest & Recovery",
    "Mind Map Momentum",
    "Today's Single Focus",
  ]);
  assert.equal(MorningBriefingOutputSchema.properties.sections.minItems, 3);
  assert.equal(MorningBriefingOutputSchema.properties.sections.maxItems, 3);
  assert.equal(
    MorningBriefingOutputSchema.properties.sections.items.additionalProperties,
    false,
  );
  assert.equal(
    MorningBriefingOutputSchema.properties.estimatedDurationSeconds.minimum,
    MORNING_BRIEFING_MIN_SECONDS,
  );
  assert.equal(
    MorningBriefingOutputSchema.properties.estimatedDurationSeconds.maximum,
    MORNING_BRIEFING_MAX_SECONDS,
  );
});

test("fallback remains TTS-ready, paced, and ID-safe", () => {
  const request = parseMorningBriefingRequest(requestValue);
  const fallback = buildFallbackMorningBriefing(request);
  const parsed = parseMorningBriefing(fallback, request);
  assert.deepEqual(
    parsed.sections.map((section) => section.title),
    MORNING_BRIEFING_SECTION_TITLES,
  );
  const wordCount = parsed.sections.reduce(
    (total, section) => total + countWords(section.ttsText),
    0,
  );
  assert.ok(wordCount >= MORNING_BRIEFING_MIN_WORDS);
  assert.ok(wordCount <= MORNING_BRIEFING_MAX_WORDS);
  assert.ok(parsed.estimatedDurationSeconds >= MORNING_BRIEFING_MIN_SECONDS);
  assert.ok(parsed.estimatedDurationSeconds <= MORNING_BRIEFING_MAX_SECONDS);
  assert.deepEqual(parsed.sections[1].highlightedClusterIds, [
    "cluster_momentum",
  ]);
  assert.deepEqual(parsed.sections[2].highlightedNodeIds, ["node_focus"]);
  assert.ok(parsed.sections.every((section) => !/[*#<>[\]{}]/u.test(section.ttsText)));
});

test("rejects wrong sections, unsafe IDs, and invalid pacing", () => {
  const request = parseMorningBriefingRequest(requestValue);
  const fallback = buildFallbackMorningBriefing(request);
  assert.throws(
    () =>
      parseMorningBriefing(
        {
          ...fallback,
          sections: [
            fallback.sections[1],
            fallback.sections[0],
            fallback.sections[2],
          ],
        },
        request,
      ),
    /title must be "Rest & Recovery"/,
  );
  assert.throws(
    () =>
      parseMorningBriefing(
        {
          ...fallback,
          sections: fallback.sections.map((section, index) =>
            index === 2
              ? { ...section, highlightedNodeIds: ["invented_node"] }
              : section,
          ),
        },
        request,
      ),
    /unknown highlighted node ID/,
  );
  assert.throws(
    () =>
      parseMorningBriefing(
        {
          ...fallback,
          sections: fallback.sections.map((section) => ({
            ...section,
            ttsText: "Too short for the requested spoken pacing.",
          })),
        },
        request,
      ),
    /spoken words/,
  );
});

test("TTS uses the validated combined script and returns MP3 base64", async () => {
  const request = parseMorningBriefingRequest(requestValue);
  const briefing = buildFallbackMorningBriefing(request);
  let receivedInput = "";
  const audioBase64 = await synthesizeMorningBriefingAudio(
    briefing,
    async (input) => {
      receivedInput = input;
      return new Response("ID3mock-mp3", {
        status: 200,
        headers: { "content-type": "audio/mpeg" },
      });
    },
  );
  assert.equal(receivedInput, combinedMorningBriefingScript(briefing));
  assert.equal(
    Buffer.from(audioBase64 ?? "", "base64").toString("utf8"),
    "ID3mock-mp3",
  );
  assert.deepEqual(buildMorningBriefingApiResponse(briefing, audioBase64), {
    briefing,
    audioBase64,
  });
});

test("TTS failure omits audio and preserves the visual briefing", async () => {
  const request = parseMorningBriefingRequest(requestValue);
  const briefing = buildFallbackMorningBriefing(request);
  const audioBase64 = await synthesizeMorningBriefingAudio(
    briefing,
    async () => {
      throw new Error("simulated TTS failure");
    },
  );
  assert.equal(audioBase64, undefined);
  assert.deepEqual(buildMorningBriefingApiResponse(briefing, audioBase64), {
    briefing,
  });
});

test("route returns non-retention headers and rejects malformed input", async () => {
  const getResponse = await GET();
  assert.equal(getResponse.status, 405);
  assert.equal(getResponse.headers.get("allow"), "POST");
  assert.match(getResponse.headers.get("cache-control") ?? "", /no-store/);
  assert.equal(getResponse.headers.get("pragma"), "no-cache");
  assert.equal(getResponse.headers.get("x-ai-data-retention"), "none");
  assert.equal(getResponse.headers.get("x-openai-store"), "false");
  assert.equal(
    MORNING_BRIEFING_PRIVACY_HEADERS["X-AI-Data-Retention"],
    "none",
  );

  const malformedResponse = await POST(
    new Request("https://example.invalid/api/morning-briefing", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-vm-client": "voicememory-mobile",
      },
      body: '{"restMetrics":',
    }),
  );
  assert.equal(malformedResponse.status, 400);
  assert.equal((await malformedResponse.json()).code, "INVALID_REQUEST");
  assert.match(malformedResponse.headers.get("cache-control") ?? "", /no-store/);
  assert.equal(malformedResponse.headers.get("x-ai-data-retention"), "none");

  const oversizedResponse = await POST(
    new Request("https://example.invalid/api/morning-briefing", {
      method: "POST",
      headers: {
        "content-length": String(MAX_MORNING_BRIEFING_BODY_BYTES + 1),
        "x-vm-client": "voicememory-mobile",
      },
      body: "{}",
    }),
  );
  assert.equal(oversizedResponse.status, 413);
  assert.match(oversizedResponse.headers.get("cache-control") ?? "", /no-store/);
});

test("route and service retain security, Structured Outputs, and metering", () => {
  const route = fs.readFileSync(
    path.join(process.cwd(), "experiments/backend/app/api/morning-briefing/route.ts"),
    "utf8",
  );
  const service = fs.readFileSync(
    path.join(
      process.cwd(),
      "backend/src/ai/morning-briefing/service.ts",
    ),
    "utf8",
  );
  assert.match(route, /export const runtime = "nodejs"/);
  assert.match(route, /export const dynamic = "force-dynamic"/);
  assert.match(route, /isAllowedVoiceSessionOrigin/);
  assert.match(route, /guardOpenAiRoute\(request, "analyze"/);
  assert.match(route, /meterConfiguredOpenAiChatUsage/);
  assert.match(route, /vendorRequestId/);
  assert.match(route, /synthesizeMorningBriefingAudio/);
  assert.match(route, /audioBase64/);
  assert.match(service, /store: false/);
  assert.match(service, /type: "json_schema"/);
  assert.match(service, /strict: true/);
  assert.match(service, /buildFallbackMorningBriefing/);
  assert.match(service, /audio\.speech\.create/);
  assert.match(service, /response_format: "mp3"/);
  assert.match(service, /toString\("base64"\)/);
  assert.doesNotMatch(service, /writeFile|createWriteStream|mkdtemp/);
  assert.doesNotMatch(
    route,
    /console\.(?:log|info|debug|warn|error)\([^)]*(?:rawBody|body|content)/s,
  );
});
