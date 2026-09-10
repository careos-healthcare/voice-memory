import { NextResponse } from "next/server";

import { isGeminiConfigured } from "@/lib/gemini";
import { generateConversationalReply } from "@/src/services/insights/conversation";
import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

function isConversationHistoryTurn(
  value: unknown,
): value is { role: "user" | "assistant"; content: string } {
  if (value === null || typeof value !== "object") {
    return false;
  }

  const turn = value as { role?: unknown; content?: unknown };
  return (
    (turn.role === "user" || turn.role === "assistant") &&
    typeof turn.content === "string"
  );
}

export async function POST(request: Request) {
  try {
    if (!isGeminiConfigured()) {
      return apiErrorResponse({
        code: "GEMINI_NOT_CONFIGURED",
        route: "insights/conversation",
      });
    }

    if (!process.env.OPENAI_API_KEY?.trim()) {
      return apiErrorResponse({
        code: "OPENAI_NOT_CONFIGURED",
        route: "insights/conversation",
      });
    }

    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "insights/conversation",
      });
    }

    let body: {
      conversationHistory?: unknown;
      message?: unknown;
    };
    try {
      body = (await request.json()) as typeof body;
    } catch {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "insights/conversation",
        internalCategory: "validation",
      });
    }

    const message = typeof body.message === "string" ? body.message.trim() : "";
    if (!message) {
      return apiErrorResponse({
        code: "MESSAGE_REQUIRED",
        route: "insights/conversation",
      });
    }

    let conversationHistory: { role: "user" | "assistant"; content: string }[] =
      [];
    if (body.conversationHistory !== undefined) {
      if (
        !Array.isArray(body.conversationHistory) ||
        !body.conversationHistory.every(isConversationHistoryTurn)
      ) {
        return apiErrorResponse({
          code: "INVALID_CONVERSATION_HISTORY",
          route: "insights/conversation",
        });
      }
      conversationHistory = body.conversationHistory;
    }

    const { reply, citedEntryIds, groundedness } =
      await generateConversationalReply(
        session.userId,
        conversationHistory,
        message,
      );

    return NextResponse.json({
      ok: true,
      reply,
      citedEntryIds,
      groundedness,
    });
  } catch (error) {
    console.error("insights/conversation failed", error);
    return apiErrorFromException(error, {
      code: "CONVERSATION_GENERATION_FAILED",
      route: "insights/conversation",
      logEvent: "api_error",
    });
  }
}
