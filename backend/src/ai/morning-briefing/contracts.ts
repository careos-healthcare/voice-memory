export const MORNING_BRIEFING_SECTION_TITLES = [
  "Rest & Recovery",
  "Mind Map Momentum",
  "Today's Single Focus",
] as const;

export const MORNING_BRIEFING_MIN_WORDS = 180;
export const MORNING_BRIEFING_MAX_WORDS = 230;
export const MORNING_BRIEFING_MIN_SECONDS = 75;
export const MORNING_BRIEFING_MAX_SECONDS = 105;
export const MAX_MORNING_BRIEFING_AUDIO_BYTES = 10 * 1024 * 1024;
export const MIN_RESTING_HEART_RATE_BPM = 30;
export const MAX_RESTING_HEART_RATE_BPM = 220;

export const MORNING_BRIEFING_PRIVACY_HEADERS = {
  "Cache-Control": "private, no-store, no-cache, must-revalidate, max-age=0",
  Pragma: "no-cache",
  Expires: "0",
  "X-Content-Type-Options": "nosniff",
  "X-AI-Data-Retention": "none",
  "X-OpenAI-Store": "false",
} as const;

const OPAQUE_ID = /^[A-Za-z0-9_-]{1,64}$/;
const FORBIDDEN_FIELD_PARTS = [
  "userid",
  "identity",
  "name",
  "email",
  "entry",
  "quote",
  "transcript",
  "text",
  "content",
  "audio",
  "media",
  "path",
] as const;

export interface MorningBriefingRequest {
  restMetrics: {
    windowDays: number;
    sleepDurationMinutes: number | null;
    sleepConsistencyScore: number | null;
    recoveryScore: number | null;
    restingHeartRateBpm: number | null;
  };
  incompleteMicroHabits: Array<{
    habitId: string;
    targetNodeId: string | null;
    completionRate: number;
    daysIncomplete: number;
  }>;
  semanticClusterVelocityDeltas: Array<{
    clusterId: string;
    velocityDelta: number;
    activityScore: number;
  }>;
  journalTopicSignals: Array<{
    topicId: string;
    relatedNodeIds: string[];
    salienceScore: number;
    velocityDelta: number;
  }>;
}

export type MorningBriefingSectionTitle =
  (typeof MORNING_BRIEFING_SECTION_TITLES)[number];

export interface MorningBriefingSection {
  title: MorningBriefingSectionTitle;
  ttsText: string;
  highlightedNodeIds: string[];
  highlightedClusterIds: string[];
}

export interface MorningBriefing {
  version: "morning-briefing-v1";
  estimatedDurationSeconds: number;
  sections: [
    MorningBriefingSection,
    MorningBriefingSection,
    MorningBriefingSection,
  ];
}

export interface MorningBriefingApiResponse {
  briefing: MorningBriefing;
  audioBase64?: string;
}

export function parseMorningBriefingRequest(
  value: unknown,
): MorningBriefingRequest {
  rejectForbiddenFields(value);
  const object = strictRecord(
    value,
    [
      "restMetrics",
      "incompleteMicroHabits",
      "semanticClusterVelocityDeltas",
      "journalTopicSignals",
    ],
    "Morning briefing request",
  );
  const rest = strictRecord(
    object.restMetrics,
    [
      "windowDays",
      "sleepDurationMinutes",
      "sleepConsistencyScore",
      "recoveryScore",
      "restingHeartRateBpm",
    ],
    "restMetrics",
  );

  const incompleteMicroHabits = boundedArray(
    object.incompleteMicroHabits,
    0,
    32,
    "incompleteMicroHabits",
  ).map((value, index) => {
    const habit = strictRecord(
      value,
      ["habitId", "targetNodeId", "completionRate", "daysIncomplete"],
      `incompleteMicroHabits[${index}]`,
    );
    return {
      habitId: opaqueId(habit.habitId, `incompleteMicroHabits[${index}].habitId`),
      targetNodeId:
        habit.targetNodeId === null
          ? null
          : opaqueId(
              habit.targetNodeId,
              `incompleteMicroHabits[${index}].targetNodeId`,
            ),
      completionRate: boundedNumber(
        habit.completionRate,
        0,
        1,
        `incompleteMicroHabits[${index}].completionRate`,
      ),
      daysIncomplete: boundedInteger(
        habit.daysIncomplete,
        1,
        365,
        `incompleteMicroHabits[${index}].daysIncomplete`,
      ),
    };
  });
  ensureUnique(
    incompleteMicroHabits.map((habit) => habit.habitId),
    "Habit IDs",
  );

  const semanticClusterVelocityDeltas = boundedArray(
    object.semanticClusterVelocityDeltas,
    0,
    32,
    "semanticClusterVelocityDeltas",
  ).map((value, index) => {
    const cluster = strictRecord(
      value,
      ["clusterId", "velocityDelta", "activityScore"],
      `semanticClusterVelocityDeltas[${index}]`,
    );
    return {
      clusterId: opaqueId(
        cluster.clusterId,
        `semanticClusterVelocityDeltas[${index}].clusterId`,
      ),
      velocityDelta: boundedNumber(
        cluster.velocityDelta,
        -1,
        1,
        `semanticClusterVelocityDeltas[${index}].velocityDelta`,
      ),
      activityScore: boundedNumber(
        cluster.activityScore,
        0,
        1,
        `semanticClusterVelocityDeltas[${index}].activityScore`,
      ),
    };
  });
  ensureUnique(
    semanticClusterVelocityDeltas.map((cluster) => cluster.clusterId),
    "Cluster IDs",
  );

  const journalTopicSignals = boundedArray(
    object.journalTopicSignals,
    0,
    32,
    "journalTopicSignals",
  ).map((value, index) => {
    const topic = strictRecord(
      value,
      ["topicId", "relatedNodeIds", "salienceScore", "velocityDelta"],
      `journalTopicSignals[${index}]`,
    );
    const relatedNodeIds = boundedArray(
      topic.relatedNodeIds,
      0,
      16,
      `journalTopicSignals[${index}].relatedNodeIds`,
    ).map((id, nodeIndex) =>
      opaqueId(
        id,
        `journalTopicSignals[${index}].relatedNodeIds[${nodeIndex}]`,
      ),
    );
    ensureUnique(relatedNodeIds, `journalTopicSignals[${index}].relatedNodeIds`);
    return {
      topicId: opaqueId(topic.topicId, `journalTopicSignals[${index}].topicId`),
      relatedNodeIds,
      salienceScore: boundedNumber(
        topic.salienceScore,
        0,
        1,
        `journalTopicSignals[${index}].salienceScore`,
      ),
      velocityDelta: boundedNumber(
        topic.velocityDelta,
        -1,
        1,
        `journalTopicSignals[${index}].velocityDelta`,
      ),
    };
  });
  ensureUnique(
    journalTopicSignals.map((topic) => topic.topicId),
    "Topic IDs",
  );

  return {
    restMetrics: {
      windowDays: boundedInteger(rest.windowDays, 1, 30, "restMetrics.windowDays"),
      sleepDurationMinutes: nullableNumber(
        rest.sleepDurationMinutes,
        0,
        1_440,
        "restMetrics.sleepDurationMinutes",
      ),
      sleepConsistencyScore: nullableNumber(
        rest.sleepConsistencyScore,
        0,
        1,
        "restMetrics.sleepConsistencyScore",
      ),
      recoveryScore: nullableNumber(
        rest.recoveryScore,
        0,
        1,
        "restMetrics.recoveryScore",
      ),
      restingHeartRateBpm: nullableNumber(
        rest.restingHeartRateBpm,
        MIN_RESTING_HEART_RATE_BPM,
        MAX_RESTING_HEART_RATE_BPM,
        "restMetrics.restingHeartRateBpm",
      ),
    },
    incompleteMicroHabits,
    semanticClusterVelocityDeltas,
    journalTopicSignals,
  };
}

export function parseMorningBriefing(
  value: unknown,
  request: MorningBriefingRequest,
): MorningBriefing {
  const object = strictRecord(
    value,
    ["version", "estimatedDurationSeconds", "sections"],
    "Morning briefing",
  );
  if (object.version !== "morning-briefing-v1") {
    throw new Error("Morning briefing version is invalid.");
  }
  const estimatedDurationSeconds = boundedInteger(
    object.estimatedDurationSeconds,
    MORNING_BRIEFING_MIN_SECONDS,
    MORNING_BRIEFING_MAX_SECONDS,
    "estimatedDurationSeconds",
  );
  const sections = boundedArray(object.sections, 3, 3, "sections").map(
    (value, index) => parseSection(value, index, request),
  ) as MorningBriefing["sections"];
  const wordCount = sections.reduce(
    (count, section) => count + countWords(section.ttsText),
    0,
  );
  if (
    wordCount < MORNING_BRIEFING_MIN_WORDS ||
    wordCount > MORNING_BRIEFING_MAX_WORDS
  ) {
    throw new Error(
      `Morning briefing must contain between ${MORNING_BRIEFING_MIN_WORDS} and ${MORNING_BRIEFING_MAX_WORDS} spoken words.`,
    );
  }
  const expectedSeconds = Math.round((wordCount / 145) * 60);
  if (Math.abs(estimatedDurationSeconds - expectedSeconds) > 12) {
    throw new Error("estimatedDurationSeconds is inconsistent with script pacing.");
  }

  return {
    version: "morning-briefing-v1",
    estimatedDurationSeconds,
    sections,
  };
}

function parseSection(
  value: unknown,
  index: number,
  request: MorningBriefingRequest,
): MorningBriefingSection {
  const object = strictRecord(
    value,
    ["title", "ttsText", "highlightedNodeIds", "highlightedClusterIds"],
    `sections[${index}]`,
  );
  const expectedTitle = MORNING_BRIEFING_SECTION_TITLES[index];
  if (object.title !== expectedTitle) {
    throw new Error(`sections[${index}].title must be "${expectedTitle}".`);
  }
  const allowedNodeIds = new Set([
    ...request.incompleteMicroHabits.flatMap((habit) =>
      habit.targetNodeId ? [habit.targetNodeId] : [],
    ),
    ...request.journalTopicSignals.flatMap((topic) => topic.relatedNodeIds),
  ]);
  const allowedClusterIds = new Set(
    request.semanticClusterVelocityDeltas.map((cluster) => cluster.clusterId),
  );
  const highlightedNodeIds = idArray(
    object.highlightedNodeIds,
    16,
    `sections[${index}].highlightedNodeIds`,
  );
  const highlightedClusterIds = idArray(
    object.highlightedClusterIds,
    16,
    `sections[${index}].highlightedClusterIds`,
  );
  if (highlightedNodeIds.some((id) => !allowedNodeIds.has(id))) {
    throw new Error(`sections[${index}] contains an unknown highlighted node ID.`);
  }
  if (highlightedClusterIds.some((id) => !allowedClusterIds.has(id))) {
    throw new Error(
      `sections[${index}] contains an unknown highlighted cluster ID.`,
    );
  }
  if (
    index === 1 &&
    allowedClusterIds.size > 0 &&
    highlightedClusterIds.length === 0
  ) {
    throw new Error("Mind Map Momentum must highlight a supplied cluster ID.");
  }
  if (index === 2 && allowedNodeIds.size > 0 && highlightedNodeIds.length === 0) {
    throw new Error("Today's Single Focus must highlight a supplied node ID.");
  }
  return {
    title: expectedTitle,
    ttsText: ttsText(object.ttsText, `sections[${index}].ttsText`),
    highlightedNodeIds,
    highlightedClusterIds,
  };
}

export function countWords(value: string): number {
  return value.trim().split(/\s+/u).filter(Boolean).length;
}

function rejectForbiddenFields(value: unknown): void {
  if (Array.isArray(value)) {
    value.forEach(rejectForbiddenFields);
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
    const normalized = key.replace(/[^a-z0-9]/gi, "").toLowerCase();
    if (FORBIDDEN_FIELD_PARTS.some((part) => normalized.includes(part))) {
      throw new Error(`Forbidden personal-content field: ${key}.`);
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

function idArray(value: unknown, max: number, label: string): string[] {
  const result = boundedArray(value, 0, max, label).map((id, index) =>
    opaqueId(id, `${label}[${index}]`),
  );
  ensureUnique(result, label);
  return result;
}

function opaqueId(value: unknown, label: string): string {
  if (typeof value !== "string" || !OPAQUE_ID.test(value)) {
    throw new Error(`${label} must be an opaque identifier.`);
  }
  return value;
}

function ttsText(value: unknown, label: string): string {
  if (
    typeof value !== "string" ||
    value.trim().length === 0 ||
    value.length > 2_000 ||
    /[\u0000-\u001F\u007F]|[*#<>[\]{}]/u.test(value)
  ) {
    throw new Error(`${label} must be plain TTS-ready text.`);
  }
  return value.trim();
}

function nullableNumber(
  value: unknown,
  min: number,
  max: number,
  label: string,
): number | null {
  return value === null ? null : boundedNumber(value, min, max, label);
}

function boundedNumber(
  value: unknown,
  min: number,
  max: number,
  label: string,
): number {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < min ||
    value > max
  ) {
    throw new Error(`${label} must be between ${min} and ${max}.`);
  }
  return value;
}

function boundedInteger(
  value: unknown,
  min: number,
  max: number,
  label: string,
): number {
  const result = boundedNumber(value, min, max, label);
  if (!Number.isInteger(result)) throw new Error(`${label} must be an integer.`);
  return result;
}

function ensureUnique(values: readonly string[], label: string): void {
  if (new Set(values).size !== values.length) {
    throw new Error(`${label} must be unique.`);
  }
}
