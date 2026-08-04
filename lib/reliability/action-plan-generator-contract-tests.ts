import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
  ACTION_PLAN_HORIZONS,
  ActionPlanGeneratorResultSchema,
  parseActionPlanGeneratorRequest,
  parseActionPlanGeneratorResult,
} from "@/lib/action-plan-generator/action-plan-generator-contract";
import {
  GET,
  MAX_ACTION_PLAN_GENERATOR_BODY_BYTES,
  POST,
} from "@/experiments/backend/app/api/action-plan-generator/route";

const simulationRequest = {
  source: "simulation_trajectory",
  nodes: [
    { id: "n_a7P2", typeToken: "pattern", weight: 0.78 },
    { id: "n_q9X1", typeToken: "constraint", weight: 0.52 },
  ],
  edges: [
    {
      id: "e_k4M8",
      sourceNodeId: "n_a7P2",
      targetNodeId: "n_q9X1",
      typeToken: "associated-with",
      weight: 0.61,
    },
  ],
  aggregateMetrics: [
    { metricToken: "node-count", value: 2 },
    { metricToken: "density", value: 0.5 },
  ],
  trajectoryData: [
    { horizonDays: 30, value: 0.22 },
    { horizonDays: 90, value: 0.38 },
    { horizonDays: 365, value: 0.46 },
  ],
} as const;

const clusterRequest = {
  source: "semantic_cluster",
  nodes: simulationRequest.nodes,
  edges: simulationRequest.edges,
  aggregateMetrics: simulationRequest.aggregateMetrics,
  clusterData: {
    categoryToken: "continuity-pattern",
    cohesion: 0.72,
    activity: 0.64,
  },
} as const;

export async function runActionPlanGeneratorContractTests(): Promise<void> {
  const parsedSimulation =
    parseActionPlanGeneratorRequest(simulationRequest);
  const parsedCluster = parseActionPlanGeneratorRequest(clusterRequest);
  assert.equal(parsedSimulation.source, "simulation_trajectory");
  assert.equal(parsedCluster.source, "semantic_cluster");
  assert.deepEqual(ACTION_PLAN_HORIZONS, [30, 90, 365]);

  const result = validResult();
  const parsedResult = parseActionPlanGeneratorResult(
    result,
    parsedSimulation,
  );
  assert.equal(parsedResult.microHabits.length, 3);
  assert.deepEqual(
    parsedResult.microHabits.map((habit) => habit.targetNodeId),
    ["n_a7P2", "n_q9X1", "n_a7P2"],
  );
  assert.equal(parsedResult.microHabits[2].stackingCue, null);
  assert.equal(ActionPlanGeneratorResultSchema.additionalProperties, false);
  assert.equal(
    ActionPlanGeneratorResultSchema.properties.microHabits.minItems,
    3,
  );
  assert.equal(
    ActionPlanGeneratorResultSchema.properties.microHabits.maxItems,
    3,
  );

  assert.throws(
    () =>
      parseActionPlanGeneratorResult(
        { ...result, microHabits: result.microHabits.slice(0, 2) },
        parsedSimulation,
      ),
    /between 3 and 3/,
  );
  assert.throws(
    () =>
      parseActionPlanGeneratorResult(
        {
          ...result,
          microHabits: result.microHabits.map((habit, index) =>
            index === 0 ? { ...habit, targetNodeId: "invented_node" } : habit,
          ),
        },
        parsedSimulation,
      ),
    /not a request node ID/,
  );
  assert.throws(
    () =>
      parseActionPlanGeneratorResult(
        {
          ...result,
          microHabits: result.microHabits.map((habit, index) =>
            index === 0
              ? {
                  ...habit,
                  frequency: "daily",
                  customWeekdays: ["monday"],
                }
              : habit,
          ),
        },
        parsedSimulation,
      ),
    /empty for daily/,
  );

  for (const forbidden of [
    { userId: "user-1" },
    { entryId: "entry-1" },
    { originalNodeId: "source-1" },
    { label: "private label" },
    { title: "private title" },
    { quote: "private words" },
    { transcript: "private words" },
    { evidence: "private evidence" },
    { content: "private content" },
    { audioPath: "/private/file.m4a" },
    { mediaUrl: "https://example.invalid/private" },
  ]) {
    assert.throws(
      () =>
        parseActionPlanGeneratorRequest({
          ...simulationRequest,
          nodes: [{ ...simulationRequest.nodes[0], ...forbidden }],
        }),
      /Forbidden personal-content field/,
    );
  }

  assert.throws(
    () =>
      parseActionPlanGeneratorRequest({
        ...simulationRequest,
        trajectoryData: [
          simulationRequest.trajectoryData[1],
          simulationRequest.trajectoryData[0],
          simulationRequest.trajectoryData[2],
        ],
      }),
    /exactly 30, 90, and 365/,
  );
  assert.throws(
    () =>
      parseActionPlanGeneratorRequest({
        ...clusterRequest,
        trajectoryData: simulationRequest.trajectoryData,
      }),
    /unknown fields/,
  );
  assert.throws(
    () =>
      parseActionPlanGeneratorRequest({
        ...simulationRequest,
        clusterData: clusterRequest.clusterData,
      }),
    /unknown fields/,
  );

  await runRouteRuntimeTests();
  runRouteStaticTests();
}

async function runRouteRuntimeTests(): Promise<void> {
  const getResponse = await GET();
  assert.equal(getResponse.status, 405);
  assert.equal(getResponse.headers.get("allow"), "POST");
  assert.match(getResponse.headers.get("cache-control") ?? "", /no-store/);
  assert.equal(getResponse.headers.get("pragma"), "no-cache");
  assert.equal(getResponse.headers.get("x-content-type-options"), "nosniff");

  const blockedResponse = await POST(
    new Request("https://example.invalid/api/action-plan-generator", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: "https://attacker.invalid",
      },
      body: JSON.stringify(simulationRequest),
    }),
  );
  assert.equal(blockedResponse.status, 403);
  assert.match(blockedResponse.headers.get("cache-control") ?? "", /no-store/);

  const invalidResponse = await POST(
    new Request("https://example.invalid/api/action-plan-generator", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-vm-client": "voicememory-mobile",
      },
      body: JSON.stringify({ ...simulationRequest, transcript: "forbidden" }),
    }),
  );
  assert.equal(invalidResponse.status, 400);
  assert.equal((await invalidResponse.json()).code, "INVALID_REQUEST");
  assert.match(invalidResponse.headers.get("cache-control") ?? "", /no-store/);

  const oversizedResponse = await POST(
    new Request("https://example.invalid/api/action-plan-generator", {
      method: "POST",
      headers: {
        "content-length": String(MAX_ACTION_PLAN_GENERATOR_BODY_BYTES + 1),
        "x-vm-client": "voicememory-mobile",
      },
      body: "{}",
    }),
  );
  assert.equal(oversizedResponse.status, 413);
  assert.match(oversizedResponse.headers.get("cache-control") ?? "", /no-store/);
}

function runRouteStaticTests(): void {
  const route = fs.readFileSync(
    path.join(process.cwd(), "experiments/backend/app/api/action-plan-generator/route.ts"),
    "utf8",
  );
  assert.match(route, /export const runtime = "nodejs"/);
  assert.match(route, /export const dynamic = "force-dynamic"/);
  assert.match(route, /32 \* 1024/);
  assert.match(route, /readBoundedBody/);
  assert.match(route, /isAllowedVoiceSessionOrigin/);
  assert.match(route, /voicememory-mobile/);
  assert.match(route, /guardOpenAiRoute\(request, "analyze"/);
  assert.match(route, /type: "json_schema"/);
  assert.match(route, /strict: true/);
  assert.match(route, /store: false/);
  assert.match(route, /meterConfiguredOpenAiChatUsage/);
  assert.match(route, /vendorRequestId/);
  assert.match(route, /two-minute rule/);
  assert.match(route, /habit stacking/);
  assert.match(route, /optional behavioral experiments/);
  assert.match(route, /Do not diagnose, provide therapy, prescribe treatment/);
  assert.doesNotMatch(
    route,
    /console\.(?:log|info|debug|warn|error)\([^)]*(?:rawBody|body|content|nodes|edges)/s,
  );
}

function validResult() {
  return {
    planTitle: "A small experiment for steadier momentum",
    targetOutcome:
      "These optional experiments may help test whether small starts support more consistent activity.",
    microHabits: [
      {
        title: "Open the task and take one small step",
        frequency: "daily",
        customWeekdays: [],
        targetNodeId: "n_a7P2",
        stackingCue: "After opening the workspace, begin for two minutes.",
      },
      {
        title: "Try one two-minute reset",
        frequency: "custom_days",
        customWeekdays: ["monday", "wednesday", "friday"],
        targetNodeId: "n_q9X1",
        stackingCue: "After the first scheduled break, try the reset.",
      },
      {
        title: "Mark whether starting felt easier",
        frequency: "daily",
        customWeekdays: [],
        targetNodeId: "n_a7P2",
        stackingCue: null,
      },
    ],
  } as const;
}
