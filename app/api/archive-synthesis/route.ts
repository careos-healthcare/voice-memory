import { NextResponse } from "next/server";

import { computeArchiveHashFromPack } from "@/lib/archive-synthesis/archive-synthesis-hash";
import {
  getCachedArchiveSynthesis,
  getCachedDeepDiveNarrative,
  getCachedHistorianReport,
  getCachedMilestoneReview,
  recordCacheHit,
  recordCacheMiss,
  setCachedArchiveSynthesis,
  setCachedDeepDiveNarrative,
  setCachedHistorianReport,
  setCachedMilestoneReview,
} from "@/lib/archive-synthesis/archive-synthesis-cache";
import {
  ARCHIVE_DEEP_DIVE_SYSTEM_PROMPT,
  ARCHIVE_HISTORIAN_SYSTEM_PROMPT,
  ARCHIVE_MILESTONE_SYSTEM_PROMPT,
  ARCHIVE_SYNTHESIS_SYSTEM_PROMPT,
  buildArchiveSynthesisUserMessage,
} from "@/lib/archive-synthesis/archive-synthesis-prompt";
import {
  parseArchiveDeepDiveNarrative,
  parseArchiveHistorianReport,
  parseArchiveMilestoneReview,
  parseArchiveMonthlyReview,
  validateArchiveDeepDiveNarrative,
  validateArchiveHistorianReport,
  validateArchiveMilestoneReview,
  validateArchiveMonthlyReview,
} from "@/lib/archive-synthesis/archive-synthesis-validator";
import {
  guardOpenAiRoute,
  apiPayloadTooLarge,
} from "@/lib/server/api-guard";
import { safeOpenAiRouteError } from "@/lib/server/openai-budget-guard";
import { getOpenAIClient } from "@/lib/openai";
import type {
  ArchiveSynthesisPack,
  ArchiveSynthesisRequestBody,
  ArchiveSynthesisResult,
  ArchiveSynthesisType,
} from "@/types/archive-synthesis";

export const runtime = "nodejs";

const MAX_PACK_BYTES = 200_000;
const MIN_ELIGIBLE = 50;
const MILESTONE_THRESHOLDS = [50, 100, 200, 500] as const;

function isSynthesisEnabled(): boolean {
  return process.env.VOICEMEMORY_ENABLE_GPT5_ARCHIVE_SYNTHESIS === "true";
}

function synthesisModel(): string {
  return (
    process.env.VOICEMEMORY_ARCHIVE_SYNTHESIS_MODEL?.trim() || "gpt-4o-mini"
  );
}

function normalizePack(pack: ArchiveSynthesisPack): ArchiveSynthesisPack {
  const primary =
    pack.primaryTheory ??
    (pack.theory
      ? {
          candidateId: "legacy-theory",
          statement: pack.theory.statement,
          confidencePercent: pack.theory.confidencePercent,
          evidenceCount: pack.theory.evidenceCount,
          counterEvidenceCount: pack.theory.counterEvidenceCount,
          rankScore: 0,
        }
      : null);
  return {
    ...pack,
    packVersion: pack.packVersion === 2 ? 2 : 1,
    primaryTheory: primary,
    secondaryTheories: pack.secondaryTheories ?? [],
  };
}

function validatePack(
  pack: ArchiveSynthesisPack,
  synthesisType: ArchiveSynthesisType,
): string | null {
  if (pack.packVersion !== 1 && pack.packVersion !== 2) {
    return "Unsupported pack version";
  }
  if (!pack.monthKey?.match(/^\d{4}-\d{2}$/)) return "Invalid monthKey";
  if (pack.eligibleCount < MIN_ELIGIBLE) {
    return `Need at least ${MIN_ELIGIBLE} eligible reflections`;
  }
  if (!pack.reflectionIndex?.length) return "Empty reflection index";
  if (synthesisType === "deep_dive" && !pack.deepDiveContext) {
    return "deepDiveContext required for deep_dive synthesis";
  }
  return null;
}

async function runSynthesis(
  systemPrompt: string,
  userMessage: string,
): Promise<string> {
  const openai = getOpenAIClient();
  const model = synthesisModel();
  const completion = await openai.chat.completions.create({
    model,
    response_format: { type: "json_object" },
    temperature: 0.4,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userMessage },
    ],
  });
  const content = completion.choices[0]?.message?.content;
  if (!content) throw new Error("SYNTHESIS_EMPTY");
  return content;
}

export async function POST(request: Request) {
  if (!isSynthesisEnabled()) {
    return NextResponse.json(
      { error: "Archive synthesis is not enabled", code: "SYNTHESIS_DISABLED" },
      { status: 403 },
    );
  }

  try {
    const rawBody = await request.text();
    if (rawBody.length > MAX_PACK_BYTES) {
      return apiPayloadTooLarge("Archive pack too large");
    }

    const body = JSON.parse(rawBody) as ArchiveSynthesisRequestBody;
    const synthesisType: ArchiveSynthesisType =
      body.synthesisType ?? "monthly";
    const pack = normalizePack(body.pack);
    if (!pack || !body.monthKey || !body.userId) {
      return NextResponse.json(
        { error: "monthKey, userId, and pack required", code: "INVALID_REQUEST" },
        { status: 400 },
      );
    }

    if (body.monthKey !== pack.monthKey) {
      return NextResponse.json(
        { error: "monthKey mismatch", code: "INVALID_REQUEST" },
        { status: 400 },
      );
    }

    const packError = validatePack(pack, synthesisType);
    if (packError) {
      return NextResponse.json(
        { error: packError, code: "INVALID_PACK" },
        { status: 400 },
      );
    }

    if (synthesisType === "milestone") {
      const threshold = body.milestoneThreshold;
      if (
        threshold == null ||
        !MILESTONE_THRESHOLDS.includes(
          threshold as (typeof MILESTONE_THRESHOLDS)[number],
        )
      ) {
        return NextResponse.json(
          { error: "milestoneThreshold must be 50, 100, 200, or 500", code: "INVALID_REQUEST" },
          { status: 400 },
        );
      }
      if (pack.eligibleCount < threshold) {
        return NextResponse.json(
          { error: "eligibleCount below milestone threshold", code: "INVALID_PACK" },
          { status: 400 },
        );
      }
    }

    const guard = await guardOpenAiRoute(request, "analyze", {
      transcriptChars: rawBody.length,
    });
    if (!guard.ok) return guard.response;

    // Pro entitlement (`pro`) is enforced on device via RevenueCat before requests.
    // Require signed-in session to limit anonymous synthesis abuse.
    if (guard.ctx.via !== "session" || !guard.ctx.userId) {
      return NextResponse.json(
        {
          error: "Sign in required for Archive Intelligence",
          code: "SYNTHESIS_REQUIRES_AUTH",
        },
        { status: 403 },
      );
    }

    const archiveHash = computeArchiveHashFromPack(pack);
    const subject = guard.ctx.userId
      ? `user:${guard.ctx.userId}`
      : guard.ctx.subject;

    if (synthesisType === "monthly") {
      const cached = getCachedArchiveSynthesis(
        subject,
        body.monthKey,
        archiveHash,
      );
      if (cached) {
        recordCacheHit();
        const response: ArchiveSynthesisResult = {
          synthesisType: "monthly",
          review: cached,
          cached: true,
        };
        return NextResponse.json(response);
      }
      recordCacheMiss();
    } else if (synthesisType === "milestone") {
      const threshold = body.milestoneThreshold!;
      const cached = getCachedMilestoneReview(subject, threshold);
      if (cached) {
        recordCacheHit();
        return NextResponse.json({
          synthesisType: "milestone",
          review: cached,
          cached: true,
        } satisfies ArchiveSynthesisResult);
      }
      recordCacheMiss();
    } else if (synthesisType === "deep_dive") {
      const cached = getCachedDeepDiveNarrative(subject, archiveHash);
      if (cached) {
        recordCacheHit();
        return NextResponse.json({
          synthesisType: "deep_dive",
          review: cached,
          cached: true,
        } satisfies ArchiveSynthesisResult);
      }
      recordCacheMiss();
    } else if (synthesisType === "historian") {
      const cached = getCachedHistorianReport(
        subject,
        body.monthKey,
        archiveHash,
      );
      if (cached) {
        recordCacheHit();
        return NextResponse.json({
          synthesisType: "historian",
          review: cached,
          cached: true,
        } satisfies ArchiveSynthesisResult);
      }
      recordCacheMiss();
    }

    const extra =
      synthesisType === "milestone"
        ? `milestoneThreshold: ${body.milestoneThreshold}\nWrite headline like "The first ${body.milestoneThreshold} reflections reveal…"`
        : synthesisType === "deep_dive"
          ? "Synthesize pack.deepDiveContext only — narrative layer."
          : synthesisType === "historian"
            ? "Focus on life changes over time — not personality traits."
            : "";

    const systemPrompt =
      synthesisType === "milestone"
        ? ARCHIVE_MILESTONE_SYSTEM_PROMPT
        : synthesisType === "deep_dive"
          ? ARCHIVE_DEEP_DIVE_SYSTEM_PROMPT
          : synthesisType === "historian"
            ? ARCHIVE_HISTORIAN_SYSTEM_PROMPT
            : ARCHIVE_SYNTHESIS_SYSTEM_PROMPT;

    const content = await runSynthesis(
      systemPrompt,
      buildArchiveSynthesisUserMessage(pack, archiveHash, extra),
    );

    const model = synthesisModel();
    const now = new Date().toISOString();

    if (synthesisType === "monthly") {
      const review = parseArchiveMonthlyReview(content);
      review.archiveHash = archiveHash;
      review.monthKey = body.monthKey;
      review.eligibleCount = pack.eligibleCount;
      review.generatedAt = review.generatedAt || now;
      review.model = model;

      const validation = validateArchiveMonthlyReview(review, pack);
      if (!validation.ok) {
        console.error("Archive synthesis validation failed:", validation.errors);
        return NextResponse.json(
          { error: "Synthesis failed evidence checks", code: "SYNTHESIS_VALIDATION_FAILED" },
          { status: 422 },
        );
      }
      setCachedArchiveSynthesis(subject, review);
      return NextResponse.json({
        synthesisType: "monthly",
        review,
        cached: false,
      } satisfies ArchiveSynthesisResult);
    }

    if (synthesisType === "milestone") {
      const review = parseArchiveMilestoneReview(content);
      review.archiveHash = archiveHash;
      review.milestoneThreshold = body.milestoneThreshold!;
      review.eligibleCount = pack.eligibleCount;
      review.generatedAt = review.generatedAt || now;
      review.model = model;

      const validation = validateArchiveMilestoneReview(review, pack);
      if (!validation.ok) {
        console.error("Milestone synthesis validation failed:", validation.errors);
        return NextResponse.json(
          { error: "Synthesis failed evidence checks", code: "SYNTHESIS_VALIDATION_FAILED" },
          { status: 422 },
        );
      }
      setCachedMilestoneReview(subject, review);
      return NextResponse.json({
        synthesisType: "milestone",
        review,
        cached: false,
      } satisfies ArchiveSynthesisResult);
    }

    if (synthesisType === "deep_dive") {
      const review = parseArchiveDeepDiveNarrative(content);
      review.archiveHash = archiveHash;
      review.beliefStatement =
        review.beliefStatement || pack.deepDiveContext!.beliefStatement;
      review.generatedAt = review.generatedAt || now;
      review.model = model;

      const validation = validateArchiveDeepDiveNarrative(review, pack);
      if (!validation.ok) {
        console.error("Deep dive synthesis validation failed:", validation.errors);
        return NextResponse.json(
          { error: "Synthesis failed evidence checks", code: "SYNTHESIS_VALIDATION_FAILED" },
          { status: 422 },
        );
      }
      setCachedDeepDiveNarrative(subject, review);
      return NextResponse.json({
        synthesisType: "deep_dive",
        review,
        cached: false,
      } satisfies ArchiveSynthesisResult);
    }

    const review = parseArchiveHistorianReport(content);
    review.archiveHash = archiveHash;
    review.monthKey = body.monthKey;
    review.eligibleCount = pack.eligibleCount;
    review.generatedAt = review.generatedAt || now;
    review.model = model;
    if (!review.title?.trim()) review.title = "What changed in your life?";

    const validation = validateArchiveHistorianReport(review, pack);
    if (!validation.ok) {
      console.error("Historian synthesis validation failed:", validation.errors);
      return NextResponse.json(
        { error: "Synthesis failed evidence checks", code: "SYNTHESIS_VALIDATION_FAILED" },
        { status: 422 },
      );
    }
    setCachedHistorianReport(subject, review);
    return NextResponse.json({
      synthesisType: "historian",
      review,
      cached: false,
    } satisfies ArchiveSynthesisResult);
  } catch (error) {
    console.error("Archive synthesis failed:", error);
    const safe = safeOpenAiRouteError("analyze", error);
    return NextResponse.json(
      { error: safe.message, code: safe.code },
      { status: 500 },
    );
  }
}
