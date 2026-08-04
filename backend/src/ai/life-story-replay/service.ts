import { Buffer } from "node:buffer";
import type { ChatCompletion } from "openai/resources/chat/completions";

import { getOpenAIClient } from "@/lib/openai";
import {
  parseLifeStoryReplayOutput,
  type LifeStoryReplayOutput,
  type LifeStoryReplayRequest,
} from "./contracts";
import { LIFE_STORY_REPLAY_SYSTEM_PROMPT } from "./prompt";
import { LifeStoryReplayOutputSchema } from "./schema";

export interface LifeStoryReplayGeneration {
  replay: LifeStoryReplayOutput;
  model: string;
  completion?: ChatCompletion;
  fallbackUsed: boolean;
}

export async function generateLifeStoryReplay(
  request: LifeStoryReplayRequest,
): Promise<LifeStoryReplayGeneration> {
  const model =
    process.env.VOICEMEMORY_LIFE_STORY_MODEL?.trim() || "gpt-4o-mini";
  let completion: ChatCompletion | undefined;
  try {
    completion = await getOpenAIClient().chat.completions.create({
      model,
      store: false,
      temperature: 0.35,
      messages: [
        { role: "system", content: LIFE_STORY_REPLAY_SYSTEM_PROMPT },
        { role: "user", content: JSON.stringify(request) },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "life_story_replay",
          strict: true,
          schema: LifeStoryReplayOutputSchema,
        },
      },
    });
    const content = completion.choices[0]?.message.content;
    if (!content) throw new Error("LIFE_STORY_REPLAY_EMPTY");
    return {
      replay: parseLifeStoryReplayOutput(JSON.parse(content), request),
      model,
      completion,
      fallbackUsed: false,
    };
  } catch {
    return {
      replay: buildFallbackLifeStoryReplay(request),
      model,
      completion,
      fallbackUsed: true,
    };
  }
}

export function buildFallbackLifeStoryReplay(
  request: LifeStoryReplayRequest,
): LifeStoryReplayOutput {
  const pointById = new Map(request.milestones.map((point) => [point.id, point]));
  const titles = [
    "Genesis",
    "Emergence",
    "The Great Pivot",
    "Expansion & Convergence",
    "The Horizon Ahead",
  ];
  return parseLifeStoryReplayOutput(
    {
      version: "life-story-replay-v1",
      title: "A Life in Motion",
      chapters: request.chapters.map((chapter, index) => {
        const points = chapter.milestoneIds
          .map((id) => pointById.get(id))
          .filter((point) => point !== undefined);
        const projected = points.some((point) => point.projected);
        const durationMs = Math.max(30_000, points.length * 9_000);
        return {
          id: chapter.id,
          title: titles[Math.min(index, titles.length - 1)],
          narration:
            `Chapter ${index + 1} traces a period where ${points.length} meaningful signals gathered into a broader pattern. ` +
            "Connections changed in density and emotional tone, revealing movement without claiming a single cause. " +
            (projected
              ? "The closing signals are possible futures rather than settled history, inviting reflection on what may come next."
              : "Seen together, these moments suggest continuity, adaptation, and the gradual emergence of a new perspective."),
          durationMs,
          cues: points.slice(0, 8).map((point, cueIndex) => ({
            offsetMs: Math.min(
              durationMs,
              Math.round((cueIndex / Math.max(points.length, 1)) * durationMs),
            ),
            nodeIds: point.nodeIds.slice(0, 8),
            clusterIds: point.clusterIds.slice(0, 4),
            emphasis: point.significance,
          })),
        };
      }),
    },
    request,
  );
}

export async function synthesizeLifeStoryAudio(
  replay: LifeStoryReplayOutput,
): Promise<Array<{ chapterId: string; audioBase64: string }>> {
  const result: Array<{ chapterId: string; audioBase64: string }> = [];
  let totalBytes = 0;
  for (const chapter of replay.chapters) {
    try {
      const response = await getOpenAIClient().audio.speech.create(
        {
          model:
            process.env.VOICEMEMORY_LIFE_STORY_TTS_MODEL?.trim() || "tts-1",
          voice:
            process.env.VOICEMEMORY_LIFE_STORY_TTS_VOICE?.trim() || "alloy",
          input: chapter.narration,
          response_format: "mp3",
        },
        { timeout: 30_000 },
      );
      if (!response.ok) continue;
      const bytes = Buffer.from(await response.arrayBuffer());
      totalBytes += bytes.byteLength;
      if (bytes.byteLength > 8 * 1024 * 1024 || totalBytes > 24 * 1024 * 1024) {
        break;
      }
      result.push({
        chapterId: chapter.id,
        audioBase64: bytes.toString("base64"),
      });
    } catch {
      // Script playback remains available through on-device TTS.
    }
  }
  return result;
}

