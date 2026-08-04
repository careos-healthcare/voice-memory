export const LIFE_STORY_REPLAY_PRIVACY_HEADERS = {
  "Cache-Control": "private, no-store, no-cache, must-revalidate, max-age=0",
  Pragma: "no-cache",
  Expires: "0",
  "X-Content-Type-Options": "nosniff",
  "X-AI-Data-Retention": "none",
  "X-OpenAI-Store": "false",
} as const;

const ID = /^[A-Za-z0-9_-]{1,96}$/;
const KINDS = new Set([
  "node",
  "relationship",
  "semanticCluster",
  "identityShift",
  "simulationMilestone",
]);

export interface LifeStoryReplayRequest {
  version: "life-story-replay-v1";
  milestones: Array<{
    id: string;
    timestampMs: number;
    kind: string;
    significance: number;
    sentiment: number;
    nodeIds: string[];
    clusterIds: string[];
    projected: boolean;
  }>;
  chapters: Array<{
    id: string;
    ordinal: number;
    startMs: number;
    endMs: number;
    milestoneIds: string[];
  }>;
}

export interface LifeStoryReplayOutput {
  version: "life-story-replay-v1";
  title: string;
  chapters: Array<{
    id: string;
    title: string;
    narration: string;
    durationMs: number;
    cues: Array<{
      offsetMs: number;
      nodeIds: string[];
      clusterIds: string[];
      emphasis: number;
    }>;
  }>;
}

function record(value: unknown, name: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${name} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function exact(
  value: unknown,
  keys: readonly string[],
  name: string,
): Record<string, unknown> {
  const result = record(value, name);
  if (
    Object.keys(result).length !== keys.length ||
    keys.some((key) => !(key in result))
  ) {
    throw new Error(`${name} fields are invalid.`);
  }
  return result;
}

function id(value: unknown, name: string): string {
  if (typeof value !== "string" || !ID.test(value)) {
    throw new Error(`${name} is invalid.`);
  }
  return value;
}

function integer(value: unknown, min: number, max: number, name: string): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < min ||
    value > max
  ) {
    throw new Error(`${name} is invalid.`);
  }
  return value;
}

function number(value: unknown, min: number, max: number, name: string): number {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < min ||
    value > max
  ) {
    throw new Error(`${name} is invalid.`);
  }
  return value;
}

function ids(value: unknown, name: string): string[] {
  if (!Array.isArray(value) || value.length > 24) {
    throw new Error(`${name} is invalid.`);
  }
  const result = value.map((item, index) => id(item, `${name}[${index}]`));
  if (new Set(result).size !== result.length) throw new Error(`${name} repeats.`);
  return result;
}

export function parseLifeStoryReplayRequest(
  value: unknown,
): LifeStoryReplayRequest {
  const body = exact(
    value,
    ["version", "milestones", "chapters"],
    "Life story replay request",
  );
  if (body.version !== "life-story-replay-v1") {
    throw new Error("Unsupported life story replay version.");
  }
  if (
    !Array.isArray(body.milestones) ||
    body.milestones.length === 0 ||
    body.milestones.length > 160 ||
    !Array.isArray(body.chapters) ||
    body.chapters.length === 0 ||
    body.chapters.length > 16
  ) {
    throw new Error("Life story replay arrays are invalid.");
  }
  const milestones = body.milestones.map((value, index) => {
    const item = exact(
      value,
      [
        "id",
        "timestampMs",
        "kind",
        "significance",
        "sentiment",
        "nodeIds",
        "clusterIds",
        "projected",
      ],
      `milestones[${index}]`,
    );
    if (typeof item.kind !== "string" || !KINDS.has(item.kind)) {
      throw new Error(`milestones[${index}].kind is invalid.`);
    }
    if (typeof item.projected !== "boolean") {
      throw new Error(`milestones[${index}].projected is invalid.`);
    }
    return {
      id: id(item.id, `milestones[${index}].id`),
      timestampMs: integer(
        item.timestampMs,
        0,
        8_640_000_000_000_000,
        `milestones[${index}].timestampMs`,
      ),
      kind: item.kind,
      significance: number(
        item.significance,
        0,
        1,
        `milestones[${index}].significance`,
      ),
      sentiment: number(
        item.sentiment,
        -1,
        1,
        `milestones[${index}].sentiment`,
      ),
      nodeIds: ids(item.nodeIds, `milestones[${index}].nodeIds`),
      clusterIds: ids(item.clusterIds, `milestones[${index}].clusterIds`),
      projected: item.projected,
    };
  });
  const milestoneIds = new Set(milestones.map((item) => item.id));
  if (milestoneIds.size !== milestones.length) throw new Error("Duplicate milestones.");
  const chapters = body.chapters.map((value, index) => {
    const item = exact(
      value,
      ["id", "ordinal", "startMs", "endMs", "milestoneIds"],
      `chapters[${index}]`,
    );
    const chapterMilestones = ids(
      item.milestoneIds,
      `chapters[${index}].milestoneIds`,
    );
    if (chapterMilestones.some((value) => !milestoneIds.has(value))) {
      throw new Error("Chapter references an unknown milestone.");
    }
    const startMs = integer(item.startMs, 0, 8_640_000_000_000_000, "startMs");
    const endMs = integer(item.endMs, startMs, 8_640_000_000_000_000, "endMs");
    return {
      id: id(item.id, `chapters[${index}].id`),
      ordinal: integer(item.ordinal, 0, 15, `chapters[${index}].ordinal`),
      startMs,
      endMs,
      milestoneIds: chapterMilestones,
    };
  });
  return { version: "life-story-replay-v1", milestones, chapters };
}

export function parseLifeStoryReplayOutput(
  value: unknown,
  request: LifeStoryReplayRequest,
): LifeStoryReplayOutput {
  const body = exact(value, ["version", "title", "chapters"], "Replay output");
  if (
    body.version !== "life-story-replay-v1" ||
    typeof body.title !== "string" ||
    body.title.trim().length < 3 ||
    body.title.length > 120 ||
    !Array.isArray(body.chapters) ||
    body.chapters.length !== request.chapters.length
  ) {
    throw new Error("Replay output is invalid.");
  }
  const allowedNodes = new Set(request.milestones.flatMap((item) => item.nodeIds));
  const allowedClusters = new Set(
    request.milestones.flatMap((item) => item.clusterIds),
  );
  const requestChapterIds = new Set(request.chapters.map((item) => item.id));
  const chapters = body.chapters.map((value, index) => {
    const item = exact(
      value,
      ["id", "title", "narration", "durationMs", "cues"],
      `output.chapters[${index}]`,
    );
    const chapterId = id(item.id, `output.chapters[${index}].id`);
    if (
      !requestChapterIds.has(chapterId) ||
      typeof item.title !== "string" ||
      item.title.trim().length < 2 ||
      item.title.length > 100 ||
      typeof item.narration !== "string" ||
      item.narration.trim().length < 40 ||
      item.narration.length > 4000 ||
      !Array.isArray(item.cues) ||
      item.cues.length > 24
    ) {
      throw new Error("Replay chapter is invalid.");
    }
    const durationMs = integer(item.durationMs, 10_000, 600_000, "durationMs");
    const cues = item.cues.map((value, cueIndex) => {
      const cue = exact(
        value,
        ["offsetMs", "nodeIds", "clusterIds", "emphasis"],
        `cues[${cueIndex}]`,
      );
      const nodeIds = ids(cue.nodeIds, `cues[${cueIndex}].nodeIds`);
      const clusterIds = ids(cue.clusterIds, `cues[${cueIndex}].clusterIds`);
      if (
        nodeIds.some((value) => !allowedNodes.has(value)) ||
        clusterIds.some((value) => !allowedClusters.has(value))
      ) {
        throw new Error("Replay cue references an unknown target.");
      }
      return {
        offsetMs: integer(cue.offsetMs, 0, durationMs, "offsetMs"),
        nodeIds,
        clusterIds,
        emphasis: number(cue.emphasis, 0, 1, "emphasis"),
      };
    });
    return {
      id: chapterId,
      title: item.title.trim(),
      narration: item.narration.trim(),
      durationMs,
      cues,
    };
  });
  return {
    version: "life-story-replay-v1",
    title: body.title.trim(),
    chapters,
  };
}

