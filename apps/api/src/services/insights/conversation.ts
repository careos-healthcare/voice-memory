import "server-only";

import { extractJsonObject } from "@/lib/analyze/parse-reflection-response";
import { getOpenAIClient } from "@/lib/openai";

import type { EvidenceMatch } from "@/src/services/ledger/retrieve";
import { retrieveEvidence } from "@/src/services/ledger/retrieve";

export type ConversationalGroundedness = "grounded" | "thin" | "none";

export interface ConversationalReply {
  reply: string;
  citedEntryIds: string[];
  groundedness: ConversationalGroundedness;
}

const CONVERSATION_MODEL =
  process.env.VOICEMEMORY_CONVERSATION_MODEL?.trim() || "gpt-4o-mini";

const RETRIEVAL_LIMIT = 5;

const CONVERSATIONAL_GROUNDEDNESS = [
  "grounded",
  "thin",
  "none",
] as const satisfies readonly ConversationalGroundedness[];

function isConversationalGroundedness(
  value: unknown,
): value is ConversationalGroundedness {
  return (
    typeof value === "string" &&
    (CONVERSATIONAL_GROUNDEDNESS as readonly string[]).includes(value)
  );
}

const CONVERSATIONAL_REPLY_JSON_SCHEMA = {
  type: "object",
  properties: {
    reply: {
      type: "string",
      description: "Conversational reply grounded in cited evidence.",
    },
    citedEntryIds: {
      type: "array",
      items: { type: "string" },
      description: "entryId values copied exactly from provided historical entries.",
    },
    groundedness: {
      type: "string",
      enum: [...CONVERSATIONAL_GROUNDEDNESS],
      description: "How strongly the reply is supported by retrieved evidence.",
    },
  },
  required: ["reply", "citedEntryIds", "groundedness"],
  additionalProperties: false,
} as const;

const SYSTEM_PROMPT = `You generate Evidence Method insights for ArchiveMe.

THE EVIDENCE METHOD — non-negotiable:
- You may only generate an insight if it is strictly proven by the provided historical entries and the current transcript.
- You must cite the exact entry IDs (entryId values) from the historical entries block. Copy them character-for-character.
- Do NOT invent past events, feelings, patterns, quotes, or entry IDs that are not in the provided context.
- Every claim in reply must be traceable to the current transcript and/or cited historical entries.

No therapy-speak, coaching, diagnosis, or generic encouragement. Quote the user's words when possible.
Never mention being an AI.

This is a multi-turn conversation, not a one-shot insight.
- Ask genuine follow-up questions grounded in cited evidence.
- If retrieval finds nothing relevant, say so plainly in reply and set groundedness to "none" rather than speculating.`;

function buildHistoricalEntriesBlock(matches: EvidenceMatch[]): string {
  if (matches.length === 0) {
    return "HISTORICAL ENTRIES: none retrieved.";
  }

  return matches
    .map(
      (match, index) =>
        `[${index + 1}] entryId: ${match.entryId}\ncreatedAt: ${match.createdAt}\nraw_text: ${match.rawText}`,
    )
    .join("\n\n");
}

function buildUserPrompt(newMessage: string, matches: EvidenceMatch[]): string {
  return `NEW MESSAGE:
${newMessage}

HISTORICAL ENTRIES (vector-retrieved from fact_ledger — only these may be cited):
${buildHistoricalEntriesBlock(matches)}

Reply to the new message. You may only cite entryId values listed above.`;
}

function parseConversationalReply(
  raw: string,
  allowedEntryIds: ReadonlySet<string>,
): ConversationalReply {
  const parsed = JSON.parse(extractJsonObject(raw)) as {
    reply?: unknown;
    citedEntryIds?: unknown;
    groundedness?: unknown;
  };

  const reply = typeof parsed.reply === "string" ? parsed.reply.trim() : "";
  const groundedness = parsed.groundedness;

  if (!reply) {
    throw new Error("Conversational reply response missing reply.");
  }
  if (typeof groundedness !== "string" || !isConversationalGroundedness(groundedness)) {
    throw new Error("Conversational reply response missing valid groundedness.");
  }
  if (!Array.isArray(parsed.citedEntryIds)) {
    throw new Error("Conversational reply response missing citedEntryIds array.");
  }

  const citedEntryIds = parsed.citedEntryIds.filter(
    (entryId): entryId is string =>
      typeof entryId === "string" && entryId.trim().length > 0,
  );

  const invalidCitation = citedEntryIds.find((entryId) => !allowedEntryIds.has(entryId));
  if (invalidCitation) {
    throw new Error(`Conversational reply cited hallucinated entryId: ${invalidCitation}`);
  }

  return {
    reply,
    citedEntryIds: [...new Set(citedEntryIds)],
    groundedness,
  };
}

export async function generateConversationalReply(
  userId: string,
  conversationHistory: { role: "user" | "assistant"; content: string }[],
  newMessage: string,
): Promise<ConversationalReply> {
  const message = newMessage.trim();
  if (!userId.trim()) {
    throw new Error("userId is required to generate a conversational reply.");
  }
  if (!message) {
    throw new Error("newMessage is required to generate a conversational reply.");
  }

  const retrievedMatches = await retrieveEvidence(userId, message, RETRIEVAL_LIMIT);
  const allowedEntryIds = new Set(retrievedMatches.map((match) => match.entryId));

  const openai = getOpenAIClient();
  const completion = await openai.chat.completions.create({
    model: CONVERSATION_MODEL,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "conversational_reply",
        strict: true,
        schema: CONVERSATIONAL_REPLY_JSON_SCHEMA,
      },
    },
    temperature: 0.35,
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      ...conversationHistory.map((turn) => ({
        role: turn.role,
        content: turn.content,
      })),
      { role: "user", content: buildUserPrompt(message, retrievedMatches) },
    ],
  });

  const content = completion.choices[0]?.message?.content;
  if (!content) {
    throw new Error("No conversational reply returned from model.");
  }

  return parseConversationalReply(content, allowedEntryIds);
}
