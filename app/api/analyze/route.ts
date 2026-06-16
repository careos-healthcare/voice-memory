import { NextResponse } from "next/server";

import { parseReflectionResponse } from "@/lib/analyze/parse-reflection-response";
import {
  analyzeRouteErrorResponse,
  classifyAnalyzeRouteError,
  logAnalyzeFailure,
  logAnalyzeStep,
} from "@/lib/server/analyze-route-errors";
import {
  guardOpenAiRoute,
  MAX_TRANSCRIPT_CHARS,
} from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { NOT_AI_JOURNAL_LINE } from "@/lib/product-copy";
import { buildEvidencePacket } from "@/lib/evidence/evidence-pipeline";
import { isWebMemoryScope } from "@/lib/evidence/evidence-policy";
import type { EvidenceCandidate } from "@/lib/evidence/evidence-source";
import {
  buildPromptContext,
  composePromptUserContent,
  logPromptContextMetadata,
} from "@/lib/evidence/prompt-context";
import { getOpenAIClient } from "@/lib/openai";
import type { Reflection } from "@/types/journal";

export const runtime = "nodejs";

const SYSTEM_PROMPT = `You read voice transcripts for ArchiveMe — ${NOT_AI_JOURNAL_LINE} Return sharp, concrete notes from the speaker's own words — not therapy, not coaching, not diagnosis.

VOICE:
- Short sentences. No filler. No warmth padding. No AI cheerleading.
- Quote the speaker's words in double quotes whenever possible.
- Name what repeats, pulls in two directions, or stays vague — plainly.
- Slightly sharp is fine; cruelty, clinical labels, and diagnosis are not.
- Observation beats recommendation. If there is no concrete next step in their words, leave it blank.

NEVER USE OR IMPLY:
- Generic encouragement, praise, or motivation
- Therapy-speak ("hold space", "inner journey", "processing", "validate", "resilience")
- "You may be seeking…", "deep-seated", vague advice, or disguised coaching
- "You should…", "Consider trying…", "Be kind to yourself…"
- Diagnosis, disorder names, or clinical labels

OUTPUT — valid JSON only, with these keys in priority order:

1. exactLanguagePattern (string, required): verbatim quote or tight paraphrase, max 20 words — their sharpest recurring phrase.
2. concreteObservation (string, required): one sentence — who, what, when, feeling — grounded in transcript.
3. tensionOrContradiction (string): one sentence on pull-between or reversal IN this entry, or "" if none.
4. repeatedSignal (string, required): one sentence on language repeated IN this entry, or "Nothing repeated clearly in this entry."
5. avoidedOrVagueArea (string): one sentence if they circle something without naming it ("that situation", "stuff", hedging), or "".
6. nextSmallAction (string): concrete next step taken FROM their words only, max 12 words, or "". Not generic advice.

Also include (internal metadata only — never shown as badges or scores in the app):
- mood: short phrase from their words, not a clinical label
- emotionalIntensity: integer 1-10 for sorting only
- recurringThemes: array of 2-4 short theme strings from the transcript

Never write third-person summaries ("the speaker expresses…"). Quote them directly.

Do NOT include hiddenConcern, positiveSignal, recommendation, or patternObservations.

If the transcript is thin, say what is missing — do not invent depth.

Never mention being an AI.`;

/**
 * Prompt Context Contract: additional context enters this route only as
 * prior-entry references (safe id + timestamp), becomes a structured
 * evidence packet, and reaches the prompt through the rendered contract
 * block. Raw archive text is never accepted or interpolated.
 */
const MAX_PRIOR_EVIDENCE_INPUTS = 20;

function toArchiveCandidates(input: unknown): EvidenceCandidate[] {
  if (!Array.isArray(input)) return [];
  return input.slice(0, MAX_PRIOR_EVIDENCE_INPUTS).flatMap((raw): EvidenceCandidate[] => {
    if (typeof raw !== "object" || raw === null) return [];
    const ref = raw as { id?: unknown; createdAt?: unknown; userConfirmed?: unknown };
    return [
      {
        sourceType: "user_archive",
        sourceRef: typeof ref.id === "string" ? ref.id : undefined,
        createdAt: typeof ref.createdAt === "string" ? ref.createdAt : undefined,
        userConfirmed: ref.userConfirmed === true,
      },
    ];
  });
}

export async function GET() {
  return NextResponse.json(
    {
      route: "/api/analyze",
      methods: ["POST"],
      captureTokenHeader: "x-vm-capture-token",
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST with JSON { transcript, priorEvidence? } and x-vm-capture-token.",
    },
    { status: 405 },
  );
}

export async function POST(request: Request) {
  let transcript = "";
  try {
    logAnalyzeStep("request_received");

    if (!process.env.OPENAI_API_KEY?.trim()) {
      return analyzeRouteErrorResponse(
        "missing_openai_key",
        "Analysis is not configured on the server.",
        503,
      );
    }

    let body: {
      transcript?: string;
      memoryScope?: unknown;
      priorEvidence?: unknown;
    };
    try {
      body = (await request.json()) as typeof body;
    } catch {
      return analyzeRouteErrorResponse(
        "invalid_request_body",
        "Request body must be valid JSON.",
        400,
      );
    }

    transcript = body.transcript?.trim() ?? "";

    if (!transcript) {
      return analyzeRouteErrorResponse(
        "transcript_required",
        "Transcript is required",
        400,
      );
    }

    if (transcript.length > MAX_TRANSCRIPT_CHARS) {
      return analyzeRouteErrorResponse(
        "transcript_too_long",
        "Transcript is too long to analyze.",
        413,
      );
    }

    logAnalyzeStep(`transcript_chars=${transcript.length}`);

    const guard = await guardOpenAiRoute(request, "analyze", {
      transcriptChars: transcript.length,
    });
    if (!guard.ok) return guard.response;

    const memoryScope = isWebMemoryScope(body.memoryScope)
      ? body.memoryScope
      : "automatic";
    const { packet } = buildEvidencePacket(toArchiveCandidates(body.priorEvidence), {
      memoryScope,
    });
    const promptContext = buildPromptContext({
      currentEntry: { transcript },
      evidencePacket: packet,
    });
    logPromptContextMetadata(promptContext);

    logAnalyzeStep("openai_request_start model=gpt-4o-mini");
    const openai = getOpenAIClient();
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      temperature: 0.35,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: `Read this voice reflection like a sharp mirror. Quote their words. Observations only:\n\n${composePromptUserContent(promptContext)}`,
        },
      ],
    });

    const content = completion.choices[0]?.message?.content;
    if (!content) {
      return analyzeRouteErrorResponse(
        "model_error",
        "No reflection returned from model",
        502,
      );
    }

    let reflection: Reflection;
    reflection = parseReflectionResponse(content, transcript);

    logAnalyzeStep(
      `success observationLength=${reflection.concreteObservation?.trim().length ?? 0}`,
    );
    return NextResponse.json({ reflection });
  } catch (error) {
    console.error("Analysis failed:", error);
    const classified = classifyAnalyzeRouteError(error);
    logAnalyzeFailure(classified.code, classified.message);
    const safe = safeOpenAiRouteError("analyze", error);
    return NextResponse.json(
      { error: safe.message, code: safe.code },
      { status: classified.status },
    );
  }
}
