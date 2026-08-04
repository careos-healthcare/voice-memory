import { Buffer } from "node:buffer";

import type { ChatCompletion } from "openai/resources/chat/completions";

import { getOpenAIClient } from "@/lib/openai";

import {
  countWords,
  MAX_MORNING_BRIEFING_AUDIO_BYTES,
  parseMorningBriefing,
  type MorningBriefing,
  type MorningBriefingApiResponse,
  type MorningBriefingRequest,
} from "./contracts";
import { MORNING_BRIEFING_SYSTEM_PROMPT } from "./prompt";
import { MorningBriefingOutputSchema } from "./schema";

export interface MorningBriefingGeneration {
  briefing: MorningBriefing;
  model: string;
  completion?: ChatCompletion;
  fallbackUsed: boolean;
}

export type MorningBriefingSpeechGenerator = (
  input: string,
) => Promise<Response>;

export async function generateMorningBriefing(
  request: MorningBriefingRequest,
): Promise<MorningBriefingGeneration> {
  const model =
    process.env.VOICEMEMORY_MORNING_BRIEFING_MODEL?.trim() || "gpt-4o-mini";
  let completion: ChatCompletion | undefined;

  try {
    completion = await getOpenAIClient().chat.completions.create({
      model,
      store: false,
      temperature: 0.2,
      messages: [
        { role: "system", content: MORNING_BRIEFING_SYSTEM_PROMPT },
        { role: "user", content: JSON.stringify(request) },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "morning_briefing",
          strict: true,
          schema: MorningBriefingOutputSchema,
        },
      },
    });
    const content = completion.choices[0]?.message.content;
    if (!content) throw new Error("MORNING_BRIEFING_EMPTY");
    return {
      briefing: parseMorningBriefing(JSON.parse(content), request),
      model,
      completion,
      fallbackUsed: false,
    };
  } catch {
    return {
      briefing: buildFallbackMorningBriefing(request),
      model,
      completion,
      fallbackUsed: true,
    };
  }
}

export function buildFallbackMorningBriefing(
  request: MorningBriefingRequest,
): MorningBriefing {
  const clusterId = [...request.semanticClusterVelocityDeltas].sort(
    (left, right) =>
      Math.abs(right.velocityDelta) - Math.abs(left.velocityDelta),
  )[0]?.clusterId;
  const nodeId =
    [...request.incompleteMicroHabits]
      .sort(
        (left, right) =>
          right.daysIncomplete - left.daysIncomplete ||
          left.completionRate - right.completionRate,
      )
      .find((habit) => habit.targetNodeId)?.targetNodeId ??
    request.journalTopicSignals[0]?.relatedNodeIds[0];

  const sections: MorningBriefing["sections"] = [
    {
      title: "Rest & Recovery",
      ttsText:
        "Good morning. Begin with recovery, without turning the numbers into a verdict. The available rest signals offer a limited snapshot, so treat them as context rather than a diagnosis. Notice whether duration, consistency, recovery, and resting heart rate appear aligned or mixed. If any measure is unavailable, leave that gap open instead of guessing. A steadier start may come from matching today's pace to the energy that is actually available.",
      highlightedNodeIds: [],
      highlightedClusterIds: [],
    },
    {
      title: "Mind Map Momentum",
      ttsText:
        "Next, look at momentum across the mind map. Recent cluster movement and journal-derived topic signals may show where attention is gathering, fading, or holding steady. These are directional aggregates, not explanations of why anything changed. Give the strongest moving cluster a moment of attention, while keeping quieter signals in perspective. The useful question is simply what appears to be gaining enough momentum to deserve deliberate space today.",
      highlightedNodeIds: [],
      highlightedClusterIds: clusterId ? [clusterId] : [],
    },
    {
      title: "Today's Single Focus",
      ttsText:
        "For today's single focus, choose one incomplete micro-habit and make the next step intentionally small. The goal is not to recover every missed day or force a perfect streak. It is to create one clear opportunity to begin. Set a brief cue, take the smallest useful action, and then reassess. If energy or circumstances change, adapting the step still counts as informed follow-through rather than failure.",
      highlightedNodeIds: nodeId ? [nodeId] : [],
      highlightedClusterIds: [],
    },
  ];
  const wordCount = sections.reduce(
    (total, section) => total + countWords(section.ttsText),
    0,
  );

  return parseMorningBriefing(
    {
      version: "morning-briefing-v1",
      estimatedDurationSeconds: Math.round((wordCount / 145) * 60),
      sections,
    },
    request,
  );
}

export function combinedMorningBriefingScript(
  briefing: MorningBriefing,
): string {
  return briefing.sections.map((section) => section.ttsText).join("\n\n");
}

export async function synthesizeMorningBriefingAudio(
  briefing: MorningBriefing,
  generateSpeech: MorningBriefingSpeechGenerator = generateOpenAiSpeech,
): Promise<string | undefined> {
  try {
    const response = await generateSpeech(combinedMorningBriefingScript(briefing));
    if (!response.ok) return undefined;
    const bytes = await readBoundedAudio(
      response,
      MAX_MORNING_BRIEFING_AUDIO_BYTES,
    );
    return bytes.length > 0 ? bytes.toString("base64") : undefined;
  } catch {
    return undefined;
  }
}

export function buildMorningBriefingApiResponse(
  briefing: MorningBriefing,
  audioBase64?: string,
): MorningBriefingApiResponse {
  return {
    briefing,
    ...(audioBase64 ? { audioBase64 } : {}),
  };
}

async function generateOpenAiSpeech(input: string): Promise<Response> {
  const model =
    process.env.VOICEMEMORY_MORNING_BRIEFING_TTS_MODEL?.trim() || "tts-1";
  const voice =
    process.env.VOICEMEMORY_MORNING_BRIEFING_TTS_VOICE?.trim() || "alloy";
  return getOpenAIClient().audio.speech.create(
    {
      model,
      voice,
      input,
      response_format: "mp3",
    },
    { timeout: 30_000 },
  );
}

async function readBoundedAudio(
  response: Response,
  maxBytes: number,
): Promise<Buffer> {
  if (!response.body) return Buffer.alloc(0);
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel();
        throw new Error("MORNING_BRIEFING_AUDIO_TOO_LARGE");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  return Buffer.concat(chunks);
}
